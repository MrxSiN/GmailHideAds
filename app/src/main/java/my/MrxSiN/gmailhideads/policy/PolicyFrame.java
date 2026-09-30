package my.MrxSiN.gmailhideads.policy;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;

/**
 * One policy request: encodes normalized facts into a frame, runs a
 * Brainfuck program over it and validates the response.
 *
 * <p>Each thread owns one frame with direct request and response buffers, so
 * a request allocates nothing once the frame exists. Encoding reads only
 * strings and class names and never calls back into Gmail, so a frame is
 * never re-entered. Anything that goes wrong leaves {@link #send} returning
 * {@code false}, and the caller leaves Gmail untouched.</p>
 */
final class PolicyFrame {

    private static final int INITIAL_REQUEST = 1024;

    private static final ThreadLocal<PolicyFrame> CURRENT = ThreadLocal.withInitial(PolicyFrame::new);

    /**
     * Name alphabet: case sensitive; only the characters of the ads package
     * prefix and the row class suffix are told apart, every other char
     * (including every non-ASCII char) is {@code NC_OTHER}.
     */
    private static final byte[] NAME_CODES = new byte[128];

    static {
        String letters = ".comglearndistwATIV";
        int[] codes = {
                BfAbi.NC_DOT, BfAbi.NC_C, BfAbi.NC_O, BfAbi.NC_M, BfAbi.NC_G, BfAbi.NC_L,
                BfAbi.NC_E, BfAbi.NC_A, BfAbi.NC_R, BfAbi.NC_N, BfAbi.NC_D, BfAbi.NC_I,
                BfAbi.NC_S, BfAbi.NC_T, BfAbi.NC_W, BfAbi.NC_UP_A, BfAbi.NC_UP_T, BfAbi.NC_UP_I,
                BfAbi.NC_UP_V
        };
        for (int index = 0; index < letters.length(); index++) {
            NAME_CODES[letters.charAt(index)] = (byte) codes[index];
        }
    }

    /** Encoded on the Java heap (fastest to fill), copied once per send. */
    private byte[] buffer = new byte[INITIAL_REQUEST];
    private ByteBuffer request = direct(INITIAL_REQUEST);
    private final ByteBuffer response = direct(BfAbi.RUNTIME_OUT_CAP);
    private int position;
    private int opcode;
    private int requestId;
    private int responseLength;
    private boolean overflow;

    private PolicyFrame() {
    }

    private static ByteBuffer direct(int capacity) {
        return ByteBuffer.allocateDirect(capacity).order(ByteOrder.LITTLE_ENDIAN);
    }

    /** The calling thread's frame, started for {@code op}. */
    static PolicyFrame begin(int op) {
        PolicyFrame frame = CURRENT.get();
        frame.opcode = op;
        frame.requestId = (frame.requestId + 1) & 0xFFFF;
        frame.position = BfAbi.HEADER_SIZE;
        frame.overflow = false;
        return frame;
    }

    // ------------------------------------------------------------ encoding

    private boolean ensure(int bytes) {
        int needed = position + bytes;
        if (needed <= buffer.length) {
            return true;
        }
        if (needed > BfAbi.RUNTIME_IN_CAP) {
            overflow = true;
            return false;
        }
        int capacity = buffer.length;
        while (capacity < needed) {
            capacity *= 2;
        }
        buffer = Arrays.copyOf(buffer, Math.min(capacity, BfAbi.RUNTIME_IN_CAP));
        return true;
    }

    int position() {
        return position;
    }

    void u8(int value) {
        if (position < buffer.length || ensure(1)) {
            buffer[position++] = (byte) value;
        }
    }

    void bool(boolean value) {
        u8(value ? 1 : 0);
    }

    /** Overwrites a byte written earlier (a count known only afterwards). */
    void patch(int at, int value) {
        if (at < position) {
            buffer[at] = (byte) value;
        }
    }

    /** The request cannot be expressed in the ABI; {@link #send} will fail. */
    void overflow() {
        overflow = true;
    }

    /** Chunked name-alphabet codes: {@code u8 k, k codes, ..., u8 0}. */
    void nameText(CharSequence value) {
        int length = value.length();
        if (!ensure(length + length / BfAbi.MAX_CHUNK + 2)) {
            return;
        }
        byte[] out = buffer;
        int at = position;
        int index = 0;
        while (index < length) {
            int chunk = Math.min(BfAbi.MAX_CHUNK, length - index);
            out[at++] = (byte) chunk;
            for (int end = index + chunk; index < end; index++) {
                char c = value.charAt(index);
                out[at++] = c < 128 ? NAME_CODES[c] : (byte) BfAbi.NC_OTHER;
            }
        }
        out[at++] = 0;
        position = at;
    }

    // ------------------------------------------------------------ execution

    /**
     * Runs {@code program}; true when a well-formed response with exactly
     * {@code expectedLength} payload bytes came back.
     */
    boolean send(int program, int expectedLength) {
        responseLength = 0;
        if (overflow || !GmailPolicy.isAvailable()) {
            return PolicyStats.failed(opcode, overflow ? PolicyStats.OVERFLOW : PolicyStats.UNAVAILABLE);
        }
        byte[] bytes = buffer;
        int payload = position - BfAbi.HEADER_SIZE;
        bytes[0] = (byte) BfAbi.ABI_MAJOR;
        bytes[1] = (byte) BfAbi.ABI_MINOR;
        bytes[2] = (byte) opcode;
        bytes[3] = 0;
        bytes[4] = (byte) payload;
        bytes[5] = (byte) (payload >>> 8);
        bytes[6] = (byte) requestId;
        bytes[7] = (byte) (requestId >>> 8);
        if (request.capacity() < position) {
            request = direct(Math.max(position, request.capacity() * 2));
        }
        ByteBuffer out = request;
        out.clear();
        out.put(bytes, 0, position);
        int length;
        try {
            length = GmailPolicy.nativeRun(program, out, position, response);
        } catch (Throwable throwable) {
            return PolicyStats.failed(opcode, PolicyStats.NATIVE);
        }
        if (length < 0) {
            return PolicyStats.failed(opcode, PolicyStats.NATIVE);
        }
        ByteBuffer in = response;
        if (length != BfAbi.HEADER_SIZE + expectedLength
                || in.get(0) != BfAbi.ABI_MAJOR
                || (in.get(2) & 0xFF) != (opcode | BfAbi.RESPONSE_BIT)
                || in.get(3) != BfAbi.ST_OK
                || (in.getShort(4) & 0xFFFF) != expectedLength
                || (in.getShort(6) & 0xFFFF) != requestId) {
            return PolicyStats.failed(opcode, PolicyStats.MALFORMED);
        }
        responseLength = expectedLength;
        PolicyStats.ok();
        return true;
    }

    /** Payload byte {@code index} of the last valid response. */
    int out(int index) {
        return index < responseLength ? response.get(BfAbi.HEADER_SIZE + index) & 0xFF : 0;
    }

    /** A verdict byte, or -1 (counted as malformed) when it is neither yes nor no. */
    int verdict(int index) {
        int value = out(index);
        if (value > BfAbi.V_YES) {
            PolicyStats.failed(opcode, PolicyStats.MALFORMED);
            return -1;
        }
        return value;
    }
}
