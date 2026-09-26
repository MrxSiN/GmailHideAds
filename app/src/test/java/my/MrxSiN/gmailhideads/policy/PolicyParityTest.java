package my.MrxSiN.gmailhideads.policy;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import com.google.android.gm.Outside;
import com.google.android.gm.ads.LookAlikes;
import com.google.android.gm.ads.adteaser.AdTeaserRows;

import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Random;

import my.MrxSiN.gmailhideads.legacy.LegacyAdTeaserViewDetector;
import my.MrxSiN.gmailhideads.legacy.LegacyGmailProfile;

/**
 * Old Java result must equal new Brainfuck result: the frozen v1.0.0 policy
 * (legacy package) against libgmailbf, on real classes, randomized names and
 * every BMP character. Randomized counts scale with -PparityCases.
 */
public class PolicyParityTest {

    private static final String PREFIX = "com.google.android.gm.ads.";
    private static final String SUFFIX = "AdTeaserItemView";
    private static final String TARGET = "com.google.android.gm";
    private static final String ROW = "com.google.android.gm.ads.adteaser.BasicAdTeaserItemView";

    private static final int CASES = HostCore.parityCases();
    private static long total;

    @BeforeClass
    public static void load() {
        HostCore.ensure();
    }

    @AfterClass
    public static void report() {
        System.out.println("PolicyParityTest: " + total + " old-vs-new comparisons");
    }

    private static synchronized void count(int cases) {
        total += cases;
    }

    private static int legacyRow(String... names) {
        for (String name : names) {
            if (LegacyAdTeaserViewDetector.matchesName(name)) {
                return 1;
            }
        }
        return 0;
    }

    private static void assertRowParity(String... names) {
        assertEquals(Arrays.toString(names), legacyRow(names), HostCore.adRow(names));
    }

    private static int legacyScope(String packageName, String processName) {
        return LegacyGmailProfile.isTargetPackage(packageName)
                && LegacyGmailProfile.isTargetProcess(processName) ? 1 : 0;
    }

    private static void assertScopeParity(String packageName, String processName) {
        assertEquals(packageName + " / " + processName, legacyScope(packageName, processName),
                GmailPolicy.inScope(packageName, processName) ? 1 : 0);
    }

    // ------------------------------------------------------------ row.bf

    @Test
    public void realClassesAndTheirSuperclasses() {
        List<Class<?>> classes = new ArrayList<>(Arrays.asList(AdTeaserRows.ROWS));
        classes.addAll(Arrays.asList(AdTeaserRows.DERIVED));
        classes.addAll(Arrays.asList(AdTeaserRows.BASE, LookAlikes.SHORTEST, LookAlikes.HOLDER,
                Outside.ROW_NAME, Object.class, String.class, Integer.class, ArrayList.class,
                HashMap.class, Thread.class, Runnable.class, int.class, int[].class, Object[].class,
                AdTeaserRows.class, PolicyParityTest.class, new Object() { }.getClass(),
                ((Runnable) () -> { }).getClass()));
        int ads = 0;
        for (Class<?> type : classes) {
            int expected = LegacyAdTeaserViewDetector.describesAdRow(type) ? 1 : 0;
            ads += expected;
            assertEquals(type.getName(), expected, GmailPolicy.adRow(type));
        }
        // Six rows, their two derived classes and the bare prefix-plus-suffix name.
        assertEquals(9, ads);
        count(classes.size());
    }

    @Test
    public void randomizedNames() {
        Random random = new Random(0x6D61696C);
        String[] pieces = {PREFIX, SUFFIX, "adteaser.", "Basic", "Video", "Ad", "Teaser", "Item", "View",
                "com.", "google.", "android.", "gm.", "ads.", ".", "$1", "x", "AAd", "é", "ﬀ",
                "\u0000", "com.google.android.gm", "Z"};
        int hits = 0;
        for (int index = 0; index < CASES; index++) {
            String[] names = new String[random.nextInt(5)];
            for (int at = 0; at < names.length; at++) {
                names[at] = randomName(random, pieces);
            }
            hits += legacyRow(names);
            assertRowParity(names);
        }
        assertTrue("randomized names should include matches", hits > CASES / 20);
        count(CASES);
    }

    private static String randomName(Random random, String[] pieces) {
        int kind = random.nextInt(10);
        if (kind < 3) {
            StringBuilder out = new StringBuilder(ROW);
            int at = random.nextInt(out.length());
            char c = "AdTeaserItemViewcom.gl xZ".charAt(random.nextInt(25));
            switch (random.nextInt(3)) {
                case 0:
                    out.insert(at, c);
                    break;
                case 1:
                    out.setCharAt(at, c);
                    break;
                default:
                    out.deleteCharAt(at);
            }
            return out.toString();
        }
        StringBuilder out = new StringBuilder();
        for (int count = random.nextInt(7); count > 0; count--) {
            out.append(pieces[random.nextInt(pieces.length)]);
        }
        return out.toString();
    }

    @Test
    public void everyBmpCharacterInEveryContext() {
        String[] contexts = {
                "%s",                                   // alone
                "%s" + ROW.substring(1),                // replaces the first prefix char
                PREFIX.substring(0, 25) + "%s" + "adteaser.Basic" + SUFFIX,  // replaces the prefix dot
                PREFIX + "adteaser.Basic%s" + SUFFIX.substring(1),           // replaces the suffix A
                ROW.substring(0, ROW.length() - 1) + "%s",                   // replaces the last char
                ROW + "%s",                             // appended
        };
        char[] one = new char[1];
        for (String context : contexts) {
            for (int c = 0; c <= 0xFFFF; c++) {
                one[0] = (char) c;
                assertRowParity(context.replace("%s", new String(one)));
            }
        }
        count(contexts.length * 0x10000);
    }

    @Test
    public void longNamesCrossChunkBorders() {
        StringBuilder middle = new StringBuilder();
        for (int length = 0; length <= 1100; length++) {
            assertRowParity(PREFIX + middle + SUFFIX);
            assertRowParity(PREFIX + middle + SUFFIX + "x");
            middle.append((char) ('a' + length % 26));
        }
        count(2 * 1101);
    }

    @Test
    public void everyClassPosition() {
        String[] ordinary = {"android.view.View", "android.view.ViewGroup", "java.lang.Object"};
        for (int length = 0; length <= 255; length += 17) {
            for (int at = 0; at <= length; at++) {
                String[] names = new String[length];
                for (int index = 0; index < length; index++) {
                    names[index] = index == at ? ROW : ordinary[index % 3];
                }
                assertRowParity(names);
                count(1);
            }
        }
    }

    // ------------------------------------------------------------ scope.bf

    @Test
    public void scopeTable() {
        String[] values = {null, "", TARGET, TARGET + ":sync", TARGET + ":widget", "com.google.android.g",
                "com.google.android.gms", "com.google.android.gmail", "Com.google.android.gm", "x", " "};
        for (String packageName : values) {
            for (String processName : values) {
                assertScopeParity(packageName, processName);
            }
        }
        count(values.length * values.length);
    }

    @Test
    public void scopeEveryBmpCharacter() {
        char[] one = new char[1];
        int cases = 0;
        for (int c = 0; c <= 0xFFFF; c++) {
            one[0] = (char) c;
            String ch = new String(one);
            String replaced = ch + TARGET.substring(1);
            String last = TARGET.substring(0, TARGET.length() - 1) + ch;
            assertScopeParity(replaced, null);
            assertScopeParity(TARGET, last);
            assertScopeParity(TARGET + ch, ch);
            cases += 3;
        }
        count(cases);
    }

    @Test
    public void scopeRandomized() {
        Random random = new Random(0x73636F70);
        String alphabet = "comgl.eandri:sx";
        for (int index = 0; index < CASES; index++) {
            assertScopeParity(randomScopeName(random, alphabet), randomScopeName(random, alphabet));
        }
        count(CASES);
    }

    private static String randomScopeName(Random random, String alphabet) {
        int kind = random.nextInt(8);
        if (kind == 0) {
            return null;
        }
        if (kind == 1) {
            return "";
        }
        if (kind < 4) {
            return TARGET;
        }
        StringBuilder out = new StringBuilder(TARGET);
        int edits = 1 + random.nextInt(2);
        for (int edit = 0; edit < edits; edit++) {
            int at = random.nextInt(out.length() + 1);
            char c = alphabet.charAt(random.nextInt(alphabet.length()));
            if (at == out.length() || random.nextBoolean()) {
                out.insert(at, c);
            } else {
                out.setCharAt(at, c);
            }
        }
        return out.toString();
    }
}
