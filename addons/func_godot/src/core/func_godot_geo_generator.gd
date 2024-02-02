extends RefCounted

# Min distance between two verts in a brush before they're merged. Higher values fix angled brushes near extents.
const CMP_EPSILON:= 0.008

const UP_VECTOR:= Vector3(0.0, 0.0, 1.0)
const RIGHT_VECTOR:= Vector3(0.0, 1.0, 0.0)
const FORWARD_VECTOR:= Vector3(1.0, 0.0, 0.0)

var map_data: FuncGodotMapData

var wind_entity_idx: int = 0
var wind_brush_idx: int = 0
var wind_FuncGodotFace_idx: int = 0
var wind_FuncGodotFace_center: Vector3
var wind_FuncGodotFace_basis: Vector3
var wind_FuncGodotFace_normal: Vector3

func _init(in_map_data: FuncGodotMapData) -> void:
	map_data = in_map_data

func sort_vertices_by_winding(a, b) -> bool:
	var FuncGodotFace:= map_data.entities[wind_entity_idx].brushes[wind_brush_idx].FuncGodotFaces[wind_FuncGodotFace_idx]
	var FuncGodotFace_geo:= map_data.entity_geo[wind_entity_idx].brushes[wind_brush_idx].FuncGodotFaces[wind_FuncGodotFace_idx]
	
	var u:= wind_FuncGodotFace_basis.normalized()
	var v:= u.cross(wind_FuncGodotFace_normal).normalized()
	
	var loc_a = a.vertex - wind_FuncGodotFace_center
	var a_pu: float = loc_a.dot(u)
	var a_pv: float = loc_a.dot(v)
	
	var loc_b = b.vertex - wind_FuncGodotFace_center
	var b_pu: float = loc_b.dot(u)
	var b_pv: float = loc_b.dot(v)
	
	var a_angle:= atan2(a_pv, a_pu)
	var b_angle:= atan2(b_pv, b_pu)
	
	return a_angle < b_angle

func run() -> void:
	# resize arrays
	map_data.entity_geo.resize(map_data.entities.size())
	for i in range(map_data.entity_geo.size()):
		map_data.entity_geo[i] = FuncGodotMapData.FuncGodotEntityGeometry.new()
	
	for e in range(map_data.entities.size()):
		var entity:= map_data.entities[e]
		var entity_geo:= map_data.entity_geo[e]
		entity_geo.brushes.resize(entity.brushes.size())
		for i in range(entity_geo.brushes.size()):
			entity_geo.brushes[i] = FuncGodotMapData.FuncGodotBrushGeometry.new()
		
		for b in range(entity.brushes.size()):
			var brush:= entity.brushes[b]
			var brush_geo:= entity_geo.brushes[b]
			brush_geo.FuncGodotFaces.resize(brush.FuncGodotFaces.size())
			for i in range(brush_geo.FuncGodotFaces.size()):
				brush_geo.FuncGodotFaces[i] = FuncGodotMapData.FuncGodotFaceGeometry.new()
	
	var generate_vertices_task = func(e):
		var entity:= map_data.entities[e]
		var entity_geo:= map_data.entity_geo[e]
		entity.center = Vector3.ZERO
		
		for b in range(entity.brushes.size()):
			var brush:= entity.brushes[b]
			brush.center = Vector3.ZERO
			var vert_count: int = 0
			
			generate_brush_vertices(e, b)
			
			var brush_geo:= map_data.entity_geo[e].brushes[b]
			for FuncGodotFace in brush_geo.FuncGodotFaces:
				for vert in FuncGodotFace.vertices:
					brush.center += vert.vertex
					vert_count += 1
			
			if vert_count > 0:
				brush.center /= float(vert_count)
			
			entity.center += brush.center
			
		if entity.brushes.size() > 0:
			entity.center /= float(entity.brushes.size())
	
	var generate_vertices_task_id:= WorkerThreadPool.add_group_task(generate_vertices_task, map_data.entities.size(), 4, true)
	WorkerThreadPool.wait_for_group_task_completion(generate_vertices_task_id)
	
	# wind FuncGodotFace vertices
	for e in range(map_data.entities.size()):
		var entity:= map_data.entities[e]
		var entity_geo:= map_data.entity_geo[e]
		
		for b in range(entity.brushes.size()):
			var brush:= entity.brushes[b]
			var brush_geo:= entity_geo.brushes[b]
			
			for f in range(brush.FuncGodotFaces.size()):
				var FuncGodotFace:= brush.FuncGodotFaces[f]
				var FuncGodotFace_geo:= brush_geo.FuncGodotFaces[f]
				
				if FuncGodotFace_geo.vertices.size() < 3:
					continue
				
				wind_entity_idx = e
				wind_brush_idx = b
				wind_FuncGodotFace_idx = f
				
				wind_FuncGodotFace_basis = FuncGodotFace_geo.vertices[1].vertex - FuncGodotFace_geo.vertices[0].vertex
				wind_FuncGodotFace_center = Vector3.ZERO
				wind_FuncGodotFace_normal = FuncGodotFace.plane_normal
				
				for v in FuncGodotFace_geo.vertices:
					wind_FuncGodotFace_center += v.vertex
				
				wind_FuncGodotFace_center /= FuncGodotFace_geo.vertices.size()
				
				FuncGodotFace_geo.vertices.sort_custom(sort_vertices_by_winding)
				wind_entity_idx = 0
	
	# index FuncGodotFace vertices
	var index_FuncGodotFaces_task:= func(e):
		var entity_geo:= map_data.entity_geo[e]
		
		for b in range(entity_geo.brushes.size()):
			var brush_geo:= entity_geo.brushes[b]
			
			for f in range(brush_geo.FuncGodotFaces.size()):
				var FuncGodotFace_geo:= brush_geo.FuncGodotFaces[f]
				
				if FuncGodotFace_geo.vertices.size() < 3:
					continue
					
				var i_count: int = 0
				FuncGodotFace_geo.indicies.resize((FuncGodotFace_geo.vertices.size() - 2) * 3)
				for i in range(FuncGodotFace_geo.vertices.size() - 2):
					FuncGodotFace_geo.indicies[i_count] = 0
					FuncGodotFace_geo.indicies[i_count + 1] = i + 1
					FuncGodotFace_geo.indicies[i_count + 2] = i + 2
					i_count += 3
					
	var index_FuncGodotFaces_task_id:= WorkerThreadPool.add_group_task(index_FuncGodotFaces_task, map_data.entities.size(), 4, true)
	WorkerThreadPool.wait_for_group_task_completion(index_FuncGodotFaces_task_id)

func generate_brush_vertices(entity_idx: int, brush_idx: int) -> void:
	var entity:= map_data.entities[entity_idx]
	var brush:= entity.brushes[brush_idx]
	var FuncGodotFace_count: int = brush.FuncGodotFaces.size()
	
	var entity_geo:= map_data.entity_geo[entity_idx]
	var brush_geo:= entity_geo.brushes[brush_idx]
	
	var phong: bool = entity.properties.get("_phong", "0") == "1"
	var phong_angle_str: String = entity.properties.get("_phong_angle", "89")
	var phong_angle: float = float(phong_angle_str) if phong_angle_str.is_valid_float() else 89.0
	
	for f0 in range(FuncGodotFace_count):
		var FuncGodotFace:= brush.FuncGodotFaces[f0]
		var FuncGodotFace_geo:= brush_geo.FuncGodotFaces[f0]
		var texture:= map_data.textures[FuncGodotFace.texture_idx]
		
		for f1 in range(FuncGodotFace_count):
			for f2 in range(FuncGodotFace_count):
				var vertex = intersect_FuncGodotFaces(brush.FuncGodotFaces[f0], brush.FuncGodotFaces[f1], brush.FuncGodotFaces[f2])
				if not vertex is Vector3:
					continue
				if not vertex_in_hull(brush.FuncGodotFaces, vertex):
					continue
				
				var merged: bool = false
				for f3 in range(f0):
					var other_FuncGodotFace_geo := brush_geo.FuncGodotFaces[f3]
					for i in range(len(other_FuncGodotFace_geo.vertices)):
						if other_FuncGodotFace_geo.vertices[i].vertex.distance_to(vertex) < CMP_EPSILON:
							vertex = other_FuncGodotFace_geo.vertices[i].vertex
							merged = true;
							break
					
					if merged:
						break
				
				var normal: Vector3
				if phong:
					var threshold:= cos((phong_angle + 0.01) * 0.0174533)
					normal = FuncGodotFace.plane_normal
					if FuncGodotFace.plane_normal.dot(brush.FuncGodotFaces[f1].plane_normal) > threshold:
						normal += brush.FuncGodotFaces[f1].plane_normal
					if FuncGodotFace.plane_normal.dot(brush.FuncGodotFaces[f2].plane_normal) > threshold:
						normal += brush.FuncGodotFaces[f2].plane_normal
					normal = normal.normalized()
				else:
					normal = FuncGodotFace.plane_normal
				
				var uv: Vector2
				var tangent: Vector4
				if FuncGodotFace.is_valve_uv:
					uv = get_valve_uv(vertex, FuncGodotFace, texture.width, texture.height)
					tangent = get_valve_tangent(FuncGodotFace)
				else:
					uv = get_standard_uv(vertex, FuncGodotFace, texture.width, texture.height)
					tangent = get_standard_tangent(FuncGodotFace)
					
				# Check for a duplicate vertex in the current FuncGodotFace.
				var duplicate_idx: int = -1
				for i in range(FuncGodotFace_geo.vertices.size()):
					if FuncGodotFace_geo.vertices[i].vertex == vertex:
						duplicate_idx = i
						break
				
				if duplicate_idx < 0:
					var new_FuncGodotFace_vert:= FuncGodotMapData.FuncGodotFaceVertex.new()
					new_FuncGodotFace_vert.vertex = vertex
					new_FuncGodotFace_vert.normal = normal
					new_FuncGodotFace_vert.tangent = tangent
					new_FuncGodotFace_vert.uv = uv
					FuncGodotFace_geo.vertices.append(new_FuncGodotFace_vert)
				elif phong:
					FuncGodotFace_geo.vertices[duplicate_idx].normal += normal
	
	# maybe optimisable? 
	for FuncGodotFace_geo in brush_geo.FuncGodotFaces:
		for i in range(FuncGodotFace_geo.vertices.size()):
			FuncGodotFace_geo.vertices[i].normal = FuncGodotFace_geo.vertices[i].normal.normalized()
	
# returns null if no intersection, else intersection vertex.
func intersect_FuncGodotFaces(f0: FuncGodotMapData.FuncGodotFace, f1: FuncGodotMapData.FuncGodotFace, f2: FuncGodotMapData.FuncGodotFace):
	var n0:= f0.plane_normal
	var n1:= f1.plane_normal
	var n2:= f2.plane_normal
	
	var denom: float = n0.cross(n1).dot(n2)
	if denom < CMP_EPSILON:
		return null
	
	return (n1.cross(n2) * f0.plane_dist + n2.cross(n0) * f1.plane_dist + n0.cross(n1) * f2.plane_dist) / denom
	
func vertex_in_hull(FuncGodotFaces: Array[FuncGodotMapData.FuncGodotFace], vertex: Vector3) -> bool:
	for FuncGodotFace in FuncGodotFaces:
		var proj: float = FuncGodotFace.plane_normal.dot(vertex)
		if proj > FuncGodotFace.plane_dist and absf(FuncGodotFace.plane_dist - proj) > CMP_EPSILON:
			return false
	
	return true
	
func get_standard_uv(vertex: Vector3, FuncGodotFace: FuncGodotMapData.FuncGodotFace, texture_width: int, texture_height: int) -> Vector2:
	var uv_out: Vector2
	var du:= absf(FuncGodotFace.plane_normal.dot(UP_VECTOR))
	var dr:= absf(FuncGodotFace.plane_normal.dot(RIGHT_VECTOR))
	var df:= absf(FuncGodotFace.plane_normal.dot(FORWARD_VECTOR))
	
	if du >= dr and du >= df:
		uv_out = Vector2(vertex.x, -vertex.y)
	elif dr >= du and dr >= df:
		uv_out = Vector2(vertex.x, -vertex.z)
	elif df >= du and df >= dr:
		uv_out = Vector2(vertex.y, -vertex.z)
	
	var angle: float = deg_to_rad(FuncGodotFace.uv_extra.rot)
	uv_out = Vector2(
		uv_out.x * cos(angle) - uv_out.y * sin(angle),
		uv_out.x * sin(angle) + uv_out.y * cos(angle))
	
	uv_out.x /= texture_width
	uv_out.y /= texture_height
	
	uv_out.x /= FuncGodotFace.uv_extra.scale_x
	uv_out.y /= FuncGodotFace.uv_extra.scale_y
	
	uv_out.x += FuncGodotFace.uv_standard.x / texture_width
	uv_out.y += FuncGodotFace.uv_standard.y / texture_height
	
	return uv_out

func get_valve_uv(vertex: Vector3, FuncGodotFace: FuncGodotMapData.FuncGodotFace, texture_width: int, texture_height: int) -> Vector2:
	var uv_out: Vector2
	var u_axis:= FuncGodotFace.uv_valve.u.axis
	var v_axis:= FuncGodotFace.uv_valve.v.axis
	var u_shift:= FuncGodotFace.uv_valve.u.offset
	var v_shift:= FuncGodotFace.uv_valve.v.offset
	
	uv_out.x = u_axis.dot(vertex);
	uv_out.y = v_axis.dot(vertex);
	
	uv_out.x /= texture_width;
	uv_out.y /= texture_height;
	
	uv_out.x /= FuncGodotFace.uv_extra.scale_x;
	uv_out.y /= FuncGodotFace.uv_extra.scale_y;
	
	uv_out.x += u_shift / texture_width;
	uv_out.y += v_shift / texture_height;
	
	return uv_out

func get_standard_tangent(FuncGodotFace: FuncGodotMapData.FuncGodotFace) -> Vector4:
	var du:= FuncGodotFace.plane_normal.dot(UP_VECTOR)
	var dr:= FuncGodotFace.plane_normal.dot(RIGHT_VECTOR)
	var df:= FuncGodotFace.plane_normal.dot(FORWARD_VECTOR)
	var dua:= absf(du)
	var dra:= absf(dr)
	var dfa:= absf(df)
	
	var u_axis: Vector3
	var v_sign: float = 0.0
	
	if dua >= dra and dua >= dfa:
		u_axis = FORWARD_VECTOR
		v_sign = signf(du)
	elif dra >= dua and dra >= dfa:
		u_axis = FORWARD_VECTOR
		v_sign = -signf(dr)
	elif dfa >= dua and dfa >= dra:
		u_axis = RIGHT_VECTOR
		v_sign = signf(df)
		
	v_sign *= signf(FuncGodotFace.uv_extra.scale_y);
	u_axis = u_axis.rotated(FuncGodotFace.plane_normal, deg_to_rad(-FuncGodotFace.uv_extra.rot) * v_sign)
	
	return Vector4(u_axis.x, u_axis.y, u_axis.z, v_sign)

func get_valve_tangent(FuncGodotFace: FuncGodotMapData.FuncGodotFace) -> Vector4:
	var u_axis:= FuncGodotFace.uv_valve.u.axis.normalized()
	var v_axis:= FuncGodotFace.uv_valve.v.axis.normalized()
	var v_sign = -signf(FuncGodotFace.plane_normal.cross(u_axis).dot(v_axis))
	
	return Vector4(u_axis.x, u_axis.y, u_axis.z, v_sign)

func get_entities() -> Array[FuncGodotMapData.FuncGodotEntityGeometry]:
	return map_data.entity_geo

func get_brush_vertex_count(entity_idx: int, brush_idx: int) -> int:
	var vertex_count: int = 0
	var brush_geo:= map_data.entity_geo[entity_idx].brushes[brush_idx]
	for FuncGodotFace in brush_geo.FuncGodotFaces:
		vertex_count += FuncGodotFace.vertices.size()
	return vertex_count
	
func get_brush_index_count(entity_idx: int, brush_idx: int) -> int:
	var index_count: int = 0
	var brush_geo:= map_data.entity_geo[entity_idx].brushes[brush_idx]
	for FuncGodotFace in brush_geo.FuncGodotFaces:
		index_count += FuncGodotFace.indicies.size()
	return index_count
