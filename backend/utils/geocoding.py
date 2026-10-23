import json
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import urlopen

class GeocodingError(Exception):
    def __init__(self, message, status_code):
        super().__init__(message)
        self.status_code = status_code


def geocode_address(address, api_key):
    address_text = (address or "").strip()
    if not address_text:
        raise GeocodingError("Address is required.", 400)

    unresolved = {
        "latitude": None,
        "longitude": None,
        "fallback_latitude": None,
        "fallback_longitude": None,
        "city": None,
        "location_source": "unresolved",
        "accuracy_radius_km": None,
    }
    if not api_key:
        return unresolved

    query = urlencode({"address": address_text, "key": api_key})
    url = f"https://maps.googleapis.com/maps/api/geocode/json?{query}"
    try:
        with urlopen(url, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, OSError, json.JSONDecodeError, UnicodeDecodeError):
        return unresolved

    if payload.get("status") in {"ZERO_RESULTS", "REQUEST_DENIED", "INVALID_REQUEST"}:
        return unresolved
    if payload.get("status") != "OK" or not payload.get("results"):
        return unresolved

    result = payload["results"][0]
    location = result.get("geometry", {}).get("location", {})
    try:
        latitude = float(location["lat"])
        longitude = float(location["lng"])
    except (KeyError, TypeError, ValueError):
        return unresolved

    city = None
    components = result.get("address_components", [])
    for component_type in ("locality", "postal_town", "administrative_area_level_2"):
        city_component = next(
            (component for component in components if component_type in component.get("types", [])),
            None,
        )
        if city_component:
            city = city_component.get("long_name")
            break

    return {
        "latitude": latitude,
        "longitude": longitude,
        "fallback_latitude": None,
        "fallback_longitude": None,
        "city": city,
        "location_source": "google_geocode",
        "accuracy_radius_km": None,
    }