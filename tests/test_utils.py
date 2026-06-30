from monk_importer.utils import parse_coordinates, parse_price, slugify, stage_id, to_bool_yn


def test_stage_id_is_deterministic() -> None:
    assert stage_id(124, "Pafos Airport") == "124-pafos-airport"


def test_slugify_handles_punctuation() -> None:
    assert slugify("Larnaka Airport (Dromolaxia, McKenzie Beach)") == (
        "larnaka-airport-dromolaxia-mckenzie-beach"
    )


def test_parse_coordinates() -> None:
    assert parse_coordinates("34.7, 32.4") == (34.7, 32.4)


def test_parse_price_range() -> None:
    assert parse_price("137-379") == ("137-379", 137.0, 379.0)


def test_yn_boolean() -> None:
    assert to_bool_yn("Y") is True
    assert to_bool_yn("N") is False

