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

    def test_link_annotation_reasons_redacted(self):
        orig = gates._link_annotations
        gates._link_annotations = lambda _p: [("URI", "ftp://" + SYN[1])]
        try:
            rs = gates._check_link_annotations(Path("x.pdf"), [SYN[0], SYN[2]])
        finally:
            gates._link_annotations = orig
        self.assertEqual(len(rs), 3)
        for s in SYN:
            self.assertNotIn(s, " ".join(rs))

    def test_redaction_is_stable_and_distinct(self):
        a, b = gates._redact_contact(SYN[0]), gates._redact_contact(SYN[1])
        self.assertEqual(a, gates._redact_contact(SYN[0]))
        self.assertNotEqual(a, b)


def _run():
    r = unittest.TextTestRunner(stream=open("/dev/null", "w")).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(T))
    return not r.wasSuccessful()


def prove_failure():
    """Two mutants: helper made identity; and each call site reverted to raw (via helper swap per site)."""
    ok = True
    real = gates._redact_contact
    gates._redact_contact = lambda v: str(v)
    c1 = _run()
    gates._redact_contact = real
    print("PROVE-FAILURE: identity-redactor mutant", "CAUGHT" if c1 else "NOT CAUGHT")
    # site mutants: re-source gates.py with one call site unredacted
    src = Path(gates.__file__).read_text()
    for name, old, new in [
        ("link-scheme site", "scheme: {_redact_contact(target)}", "scheme: {target!r}"),
        ("link-label site", "contact: {_redact_contact(label)}", "contact: {label}"),
        ("intact site", "text layer: {_redact_contact(u)}", "text layer: {u}"),
    ]:
        assert old in src, name
        ns = {"__name__": "gates_mut", "__file__": gates.__file__}
        mod = type(sys)("gates_mut")
        mod.__dict__.update(ns)
        sys.modules["gates_mut"] = mod
        exec(compile(src.replace(old, new), gates.__file__, "exec"), mod.__dict__)
        globals()["gates"] = mod
        c = _run()
        globals()["gates"] = sys.modules["_tools.career.gates"]
        print(f"PROVE-FAILURE: {name} mutant", "CAUGHT" if c else "NOT CAUGHT")
        ok = ok and c
    return 0 if (ok and c1) else 1


if __name__ == "__main__":
    if "--prove-failure" in sys.argv:
        sys.exit(prove_failure())
    unittest.main()
