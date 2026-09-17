import sys
from pathlib import Path

# Add project root to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from aircard_backend import parse_passthm_archive, KEYPAD_SUBTEXTS


def verify_archive_extraction(passthm_path: str, name: str):
    telephony_ver = "TelephonyUI-10"
    items = parse_passthm_archive(passthm_path, telephony_ver)
    
    assert len(items) > 0, f"No items returned for {name}"
    
    leaves = [item[1] for item in items]
    target_dirs = [item[0] for item in items]
    
    # Check deduplication
    assert len(leaves) == len(set(leaves)), f"Duplicate filenames found in output for {name}"
    
    # Target directory verification
    expected_dir = f"/var/mobile/Library/Caches/{telephony_ver}"
    for tdir in target_dirs:
        assert tdir == expected_dir, f"Unexpected target directory: {tdir}"
        
    for d in range(10):
        digit = str(d)
        
        # Must have blank subtext variants for en- and other-
        en_blank = f"en-{digit}---white.png"
        other_blank = f"other-{digit}---white.png"
        assert en_blank in leaves, f"Missing {en_blank} for digit {digit} in {name}"
        assert other_blank in leaves, f"Missing {other_blank} for digit {digit} in {name}"
        
        # Must have standard subtext variants if subtext is defined
        subtext = KEYPAD_SUBTEXTS.get(digit, "")
        if subtext:
            en_sub = f"en-{digit}-{subtext}--white.png"
            other_sub = f"other-{digit}-{subtext}--white.png"
            assert en_sub in leaves, f"Missing {en_sub} for digit {digit} in {name}"
            assert other_sub in leaves, f"Missing {other_sub} for digit {digit} in {name}"

    print(f"✓ {name} parsed all 10 digits with en-, other-, blank, and subtext variants successfully")


def test_minepass_nightly():
    minepass_path = "/Users/mak5er/Downloads/MinePass_Nightly.passthm"
    verify_archive_extraction(minepass_path, "MinePass_Nightly.passthm")


def test_tck():
    tck_path = "/Users/mak5er/Downloads/AyuGram Desktop/тцк.passthm"
    verify_archive_extraction(tck_path, "тцк.passthm")


if __name__ == "__main__":
    test_minepass_nightly()
    test_tck()
    print("All backend passthm tests passed successfully!")
