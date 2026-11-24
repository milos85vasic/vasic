"""JSK-T179 guard: gate failure reasons must never print a contact address/URL.

Run: python3 test_reason_redaction.py            (expect rc 0)
     python3 test_reason_redaction.py --prove-failure   (un-redacted mutant must be caught: rc 0 only if caught)
"""
import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from _tools.career import gates

SYN = ["jane.doe@example.invalid", "example.invalid/jane", "github.com/jane-doe-synthetic"]


def reasons():
    return gates._check_contact_urls("nothing matches here", SYN)


class T(unittest.TestCase):
    def test_no_contact_in_reasons(self):
        joined = " ".join(reasons())
        for s in SYN:
            self.assertNotIn(s, joined)
        self.assertEqual(len(reasons()), len(SYN))  # still one reason per contact

    def test_redaction_is_stable_and_distinct(self):
        a, b = gates._redact_contact(SYN[0]), gates._redact_contact(SYN[1])
        self.assertEqual(a, gates._redact_contact(SYN[0]))
        self.assertNotEqual(a, b)


def prove_failure():
    gates._redact_contact = lambda v: str(v)  # mutant: un-redacted
    r = unittest.TextTestRunner(stream=open("/dev/null", "w")).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(T))
    caught = not r.wasSuccessful()
    print("PROVE-FAILURE: un-redacted mutant", "CAUGHT" if caught else "NOT CAUGHT")
    return 0 if caught else 1


if __name__ == "__main__":
    if "--prove-failure" in sys.argv:
        sys.exit(prove_failure())
    unittest.main()
