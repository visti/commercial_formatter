import csv
from lib.delete_columns import remove_delete_columns_and_empty_rows

def test_remove_delete_columns_and_empty_rows(tmp_path):
    csv_path = tmp_path / "sample.csv"
    rows = [
        ["Main Artist", "Track Title", "DELETE", "Other"],
        ["Artist1", "Title1", "foo", "Other1"],
        ["Artist2", "", "bar", "Other2"],
        ["", "Title3", "baz", "Other3"],
        ["Artist4", "Title4", "qux", "Other4"],
    ]
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=';')
        writer.writerows(rows)

    remove_delete_columns_and_empty_rows(str(csv_path))

    with open(csv_path, newline='', encoding='utf-8') as f:
        reader = list(csv.reader(f, delimiter=';'))

    assert reader == [
        ["Main Artist", "Track Title", "Other"],
        ["Artist1", "Title1", "Other1"],
        ["Artist4", "Title4", "Other4"],
    ]
