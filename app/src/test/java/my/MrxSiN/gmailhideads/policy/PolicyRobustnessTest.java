package my.MrxSiN.gmailhideads.policy;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import com.google.android.gm.ads.adteaser.AdTeaserRows;

import org.junit.BeforeClass;
import org.junit.Test;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import my.MrxSiN.gmailhideads.legacy.LegacyAdTeaserViewDetector;
import my.MrxSiN.gmailhideads.legacy.LegacyGmailProfile;

/** Malformed frames, fail-open paths, determinism and concurrency. */
public class PolicyRobustnessTest {

    @BeforeClass
    public static void load() {
        HostCore.ensure();
    }

    private static ByteBuffer direct(byte[] bytes, int capacity) {
        ByteBuffer buffer = ByteBuffer.allocateDirect(Math.max(capacity, 1)).order(ByteOrder.LITTLE_ENDIAN);
        buffer.put(bytes);
        return buffer;
    }

    private static byte[] run(int program, byte[] request) {
        ByteBuffer out = ByteBuffer.allocateDirect(BfAbi.RUNTIME_OUT_CAP);
        int length = GmailPolicy.nativeRun(program, direct(request, request.length), request.length, out);
        if (length < 0) {
            return new byte[]{(byte) length};
        }
        byte[] result = new byte[length];
        out.get(result);
        return result;
    }

    private static byte[] frame(int major, int op, byte[] payload) {
        byte[] out = new byte[BfAbi.HEADER_SIZE + payload.length];
        out[0] = (byte) major;
        out[2] = (byte) op;
        out[4] = (byte) payload.length;
        out[5] = (byte) (payload.length >> 8);
        out[6] = 0x34;
        out[7] = 0x12;
        System.arraycopy(payload, 0, out, BfAbi.HEADER_SIZE, payload.length);
        return out;
    }

    @Test
    public void randomBytesNeverCrashAndStayBounded() {
        Random random = new Random(0xBAD);
        int[] programs = {BfAbi.PROG_ROW, BfAbi.PROG_SCOPE};
        int[] ops = {BfAbi.OP_AD_ROW, BfAbi.OP_SCOPE};
        int cases = HostCore.parityCases();
        for (int index = 0; index < cases; index++) {
            byte[] payload = new byte[random.nextInt(700)];
            random.nextBytes(payload);
            byte[] request = random.nextInt(5) == 0 ? payload
                    : frame(1, random.nextInt(4) == 0 ? random.nextInt(256) : ops[random.nextInt(ops.length)], payload);
            byte[] response = run(programs[random.nextInt(programs.length)], request);
            // A response, or a negative status of 1 byte: never a crash, never more than the cap.
            assertTrue(response.length <= BfAbi.RUNTIME_OUT_CAP);
            if (response.length == 1) {
                assertEquals("only the budget may stop a policy program", -3, response[0]);
            }
        }
    }

    @Test
    public void invalidProgramsAndBuffersFailCleanly() {
        byte[] request = frame(1, BfAbi.OP_SCOPE, new byte[0]);
        for (int program : new int[]{-1, 2, 255, Integer.MAX_VALUE}) {
            assertEquals(-4, run(program, request)[0]);
        }
        ByteBuffer out = ByteBuffer.allocateDirect(64);
        assertTrue(GmailPolicy.nativeRun(BfAbi.PROG_SCOPE, null, 0, out) < 0);
        assertTrue(GmailPolicy.nativeRun(BfAbi.PROG_SCOPE, direct(request, 8), 9, out) < 0);
        assertTrue(GmailPolicy.nativeRun(BfAbi.PROG_SCOPE, direct(request, 8), -1, out) < 0);
        assertTrue(GmailPolicy.nativeRun(BfAbi.PROG_SCOPE, ByteBuffer.allocate(8), 8, out) < 0);
    }

    @Test
    public void versionAndOpcodeMismatchesAreRefused() {
        for (int program : new int[]{BfAbi.PROG_ROW, BfAbi.PROG_SCOPE}) {
            byte[] badVersion = run(program, frame(2, BfAbi.OP_AD_ROW, new byte[]{1, 2, 3}));
            assertEquals(BfAbi.ST_BAD_VERSION, badVersion[3]);
            byte[] badOp = run(program, frame(1, 0x7F, new byte[]{1, 2, 3}));
            assertEquals(BfAbi.ST_BAD_OPCODE, badOp[3]);
            assertEquals(BfAbi.HEADER_SIZE, badOp.length);
        }
    }

    @Test
    public void everyTruncationOfAValidRequestIsAnswered() {
        // OP_AD_ROW, one name: "com.google.android.gm.ads.AdTeaserItemView" as name codes.
        byte[] name = {2, 3, 4, 1, 5, 3, 3, 5, 6, 7, 1, 8, 9, 10, 11, 3, 12, 10, 1, 5, 4, 1, 8, 10, 13, 1,
                16, 10, 17, 7, 8, 13, 7, 11, 18, 14, 7, 4, 19, 12, 7, 15};
        byte[] payload = new byte[name.length + 3];
        payload[0] = 1;
        payload[1] = (byte) name.length;
        System.arraycopy(name, 0, payload, 2, name.length);
        byte[] full = frame(1, BfAbi.OP_AD_ROW, payload);
        byte[] expected = run(BfAbi.PROG_ROW, full);
        assertEquals(BfAbi.V_YES, expected[8]);
        for (int length = 0; length < full.length; length++) {
            byte[] prefix = new byte[length];
            System.arraycopy(full, 0, prefix, 0, length);
            byte[] response = run(BfAbi.PROG_ROW, prefix);
            assertTrue(response.length >= BfAbi.HEADER_SIZE);
            // Only the final chunk terminator may be missing: end of input reads as 0.
            if (length >= BfAbi.HEADER_SIZE) {
                assertEquals(length == full.length - 1 ? BfAbi.V_YES : BfAbi.V_NO, response[8]);
            }
        }
    }

    @Test
    public void oversizedRequestsFailOpen() {
        StringBuilder huge = new StringBuilder("com.google.android.gm.ads.");
        while (huge.length() <= BfAbi.RUNTIME_IN_CAP) {
            huge.append("AdTeaserItemView");
        }
        long failures = PolicyStats.failures();
        // The request cannot be sent, so even an ad row name answers "failed".
        assertEquals(-1, HostCore.adRow(huge));
        assertTrue(PolicyStats.failures() > failures);
    }

    @Test
    public void sameRequestSameResponse() {
        Random random = new Random(3);
        for (int index = 0; index < 2000; index++) {
            byte[] payload = new byte[random.nextInt(300)];
            random.nextBytes(payload);
            int program = random.nextInt(2);
            byte[] request = frame(1, program == 0 ? BfAbi.OP_AD_ROW : BfAbi.OP_SCOPE, payload);
            assertArrayEquals(run(program, request), run(program, request));
        }
    }

    @Test
    public void concurrentRequestsMatchSequentialOnes() throws Exception {
        final Class<?>[] classes = {AdTeaserRows.ROWS[0], AdTeaserRows.DERIVED[0], AdTeaserRows.BASE,
                String.class, ArrayList.class, Thread.class, AdTeaserRows.ROWS[5]};
        ExecutorService pool = Executors.newFixedThreadPool(8);
        try {
            List<Future<Integer>> futures = new ArrayList<>();
            for (int thread = 0; thread < 8; thread++) {
                final int seed = thread;
                futures.add(pool.submit(new Callable<Integer>() {
                    @Override
                    public Integer call() {
                        Random random = new Random(seed);
                        int mismatches = 0;
                        for (int index = 0; index < 5000; index++) {
                            Class<?> type = classes[random.nextInt(classes.length)];
                            int expected = LegacyAdTeaserViewDetector.describesAdRow(type) ? 1 : 0;
                            if (random.nextBoolean()) {
                                mismatches += GmailPolicy.adRow(type) == expected ? 0 : 1;
                            } else {
                                String process = random.nextBoolean() ? "" : "com.google.android.gm:sync";
                                boolean expectedScope = LegacyGmailProfile.isTargetProcess(process);
                                mismatches += GmailPolicy.inScope("com.google.android.gm", process)
                                        == expectedScope ? 0 : 1;
                            }
                        }
                        return mismatches;
                    }
                }));
            }
            for (Future<Integer> future : futures) {
                assertEquals(Integer.valueOf(0), future.get());
            }
        } finally {
            pool.shutdownNow();
        }
    }
}
