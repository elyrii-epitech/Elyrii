"""Compare recorded samples without hiding regressions or discarding outliers."""
import json
import pathlib
import sys


def main():
    output = pathlib.Path(sys.argv[1])
    before = json.loads((output / "before.json").read_text())
    after = json.loads((output / "after.json").read_text())
    rows = []
    for name, old in before["results"].items():
        new = after["results"][name]
        old_ms = old["milliseconds"]["median"]
        new_ms = new["milliseconds"]["median"]
        rows.append({
            "case": name,
            "before_median_ms": old_ms,
            "after_median_ms": new_ms,
            "median_change_percent": (new_ms / old_ms - 1) * 100,
            "before_p95_ms": old["milliseconds"]["p95"],
            "after_p95_ms": new["milliseconds"]["p95"],
            "before_samples": len(old["milliseconds"]["samples"]),
            "after_samples": len(new["milliseconds"]["samples"]),
        })
    (output / "comparison.json").write_text(json.dumps({
        "baseline_commit": before["baseline_commit"],
        "scope": before["scope"],
        "cases": rows,
    }, indent=2) + "\n")
    lines = [
        "| Case | Before median (ms) | After median (ms) | Change | Before p95 | After p95 |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        lines.append(
            f"| {row['case']} | {row['before_median_ms']:.3f} | "
            f"{row['after_median_ms']:.3f} | {row['median_change_percent']:+.1f}% | "
            f"{row['before_p95_ms']:.3f} | {row['after_p95_ms']:.3f} |"
        )
    (output / "comparison.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
