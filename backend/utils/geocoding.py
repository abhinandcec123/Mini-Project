import json
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import urlopen


class GeocodingError(Exception):
    def __init__(self, message, status_code):
        super().__init__(message)
        self.status_code = status_code


def geocode_address(address, api_key):
    if not api_key:
        raise GeocodingError("Google Maps Geocoding is not configured on the server.", 503)

    query = urlencode({"address": address, "key": api_key})
    url = f"https://maps.googleapis.com/maps/api/geocode/json?{query}"
    try:
        with urlopen(url, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, OSError, json.JSONDecodeError, UnicodeDecodeError) as error:
        raise GeocodingError("Google Maps address lookup is temporarily unavailable.", 502) from error

    if payload.get("status") == "ZERO_RESULTS":
        raise GeocodingError("Google Maps could not find that address. Check it and try again.", 422)
    if payload.get("status") != "OK" or not payload.get("results"):
        raise GeocodingError("Google Maps could not verify the address. Check the Maps API configuration.", 502)

    result = payload["results"][0]
    location = result.get("geometry", {}).get("location", {})
    try:
        latitude = float(location["lat"])
        longitude = float(location["lng"])
    except (KeyError, TypeError, ValueError) as error:
        raise GeocodingError("Google Maps returned an invalid location for that address.", 502) from error

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

    return {"latitude": latitude, "longitude": longitude, "city": city}