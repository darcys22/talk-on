class_name Strike
extends RefCounted
## Pure maths for where weapons land. No scene access, so it is easy to test.
##
## Positions are "EN" vectors: x = metres east of the tower, y = metres north.


static func dir_from_bearing(deg: float) -> Vector2:
	var r := deg_to_rad(deg)
	return Vector2(sin(r), cos(r))


## Returns the ground points where this flight's weapons hit.
static func impact_points(
		ac: Dictionary,
		aim: Vector2,
		heading: float,
		wind_from: float,
		wind_speed: float,
		marked: bool,
		rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var dir := dir_from_bearing(heading)
	var downwind := dir_from_bearing(wind_from + 180.0)
	var cep := float(ac.get("cep", 20.0)) * (0.4 if marked else 1.0)
	var sigma := cep * 0.6
	var centre := aim + Vector2(rng.randfn(0.0, sigma), rng.randfn(0.0, sigma))
	centre += downwind * wind_speed * float(ac.get("wind_drift", 0.0))

	match str(ac.get("weapon", "bomb")):
		"strafe":
			var half := float(ac.get("length", 200.0)) * 0.5
			var d := -half
			while d <= half + 0.01:
				points.append(centre + dir * d)
				d += 20.0
		"stick":
			var count := int(ac.get("count", 6))
			var spacing := float(ac.get("spacing", 45.0))
			for i in count:
				points.append(centre + dir * ((i - (count - 1) * 0.5) * spacing))
		"rockets":
			for i in int(ac.get("count", 4)):
				points.append(centre + Vector2(rng.randfn(0.0, 12.0), rng.randfn(0.0, 12.0)))
		_:
			points.append(centre)
	return points
