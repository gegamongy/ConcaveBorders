extends Node3D

@onready var region_flagpoles = get_node('flagpoles')
@onready var UI = get_node('UI/Control')

var triangle_was_erased = false

func _ready():
	generate_borders()
	pass
	
func generate_borders():
	
	#Clear UI
	for i in UI.get_children():
		UI.remove_child(i)
		
	var flagpoles = region_flagpoles.get_children()
	
	#Need points
	var points = get_points_from_flagpoles(flagpoles)
	
	var triangles = get_delaunay_triangles(points)
	
	#Get boundary lines from triangles
	var boundaries = get_boundaries(triangles)

	var boundary_triangles = get_boundary_triangles(triangles, boundaries)
	
	var concave_points = get_concave_points(points, boundaries)

	var concave_points_current_index = 0
	
	while concave_points.size() > 0:
		
		var concave_point = concave_points[concave_points_current_index]
		
		var concave_triangles = get_concave_triangles(concave_point, boundary_triangles)
		
		print('# conc tris: ', concave_triangles.size())
		
		while concave_triangles.size() > 0:
			
			triangles = remove_triangle(triangles, concave_triangles, boundaries)
		
			if triangle_was_erased:
				#Triangle removed, now recalculate
				boundaries = get_boundaries(triangles)
				boundary_triangles = get_boundary_triangles(triangles, boundaries)
				#points = get_points_from_triangles(triangles) #FUNCTION not needed because points stays the same after recalculations
				concave_points = get_concave_points(points, boundaries)
			
				concave_points_current_index = 0
				
			#If no triangles were erased, its time to break and go to next cocncave point
			break
				
		if triangle_was_erased:
			triangle_was_erased = false
			continue 
			
		if concave_points_current_index + 1 == concave_points.size():
			#This is at the end of the loop
			for triangle in triangles:
				polygon(triangle)
			break
			
		if concave_points_current_index + 1 < concave_points.size():
			concave_points_current_index += 1;
			continue
		else:
			concave_points_current_index = 0

	
func get_points_from_flagpoles(flagpoles):
	var points = PackedVector2Array()
	
	for flag in flagpoles:
		points.append(Vector2(flag.global_position.x, flag.global_position.z))
		
	return points

func get_points_from_triangles(triangles: Array) -> Array:
	#The first time we get "points" is with the get_points_from_flagpole_group
	#Now we need to regenerate a new set of points from our NEW set of triangles after processing
	var points_set := {} # Using a set (dictionary keys) to store unique points
	
	for triangle in triangles:
		for point in triangle:
			points_set[point] = true # Add point to the set
	
	var points := [] # Array to store the unique points
	for point in points_set.keys():
		points.append(point)
	
	return points


func get_delaunay_triangles(points):
	var triangulate = Geometry2D.triangulate_delaunay(points)
	var triangles = []
	#For each triangle
	for i in len(triangulate)/3:
		var triangle = PackedVector2Array()
		#For each point in triangle
		for n in range(3):
			var point = Vector2(points[triangulate[(i * 3) + n]].x, points[triangulate[(i * 3) + n]].y)  #This part confuses me
			triangle.append(point)
			
		triangles.append(triangle)
	return triangles

func get_boundaries(triangles):
	
	# Iterate over each triangle
	var edges = []
	var inner_edges = []
	var outer_edges = []
	
	for triangle in triangles:
		# Iterate over each edge in the triangle
		
		for i in range(3):
			# Define the edge as a tuple of vertex indices
			var edge = [triangle[i], triangle[(i + 1) % 3]]
			# Sort the edge vertices to ensure consistency
			edge.sort()
			
			#If edge is already in list, remove from edges and put into inner_edges
			edges.append(edge)
			
	var edge_occurrences = {}
	# Count occurrences of each value
	for edge in edges:
		
		if edge_occurrences.has(edge):
			edge_occurrences[edge] += 1
			
		else:
			edge_occurrences[edge] = 1


	# Separate values based on occurrence
	for key in edge_occurrences.keys():
		if edge_occurrences[key] == 1:
			outer_edges.append(key)

		elif edge_occurrences[key] == 2:
			
			inner_edges.append(key)
	
	#Draw lines for debugging
	for edge in outer_edges:
		#line(edge[0], edge[1])
		pass
		
	return outer_edges
	
func get_boundary_triangles(triangles, outer_edges):
	
	#Look for outer edges in triangles, and add triangle to outer triangles
	var boundary_triangles = []

	for triangle in triangles:
		
		# Iterate over each edge in the triangle
		for i in range(3):
			# Define the edge as a tuple of vertex indices
			var edge = [triangle[i], triangle[(i + 1) % 3]]
			edge.sort()
			if outer_edges.has(edge):
				boundary_triangles.append(triangle)
				
	for tri in boundary_triangles:
		
		#polygon(tri)
		pass
	return boundary_triangles

func get_concave_points(points, edges):
	
	var concave_points = []
	#Shrink the polygon so bordering 
	var shape_points = sort_vertices_around_edge(edges)
	var sorted_edges = sort_edges(shape_points)

	var deflated_points = scale_points_by_normals(shape_points, sorted_edges, .1) #PROP DRILLING - DONT DO THIS
	
	for point in points:
		var point_is_concave = Geometry2D.is_point_in_polygon(point, deflated_points)
		
		if point_is_concave:
			concave_points.append(point)

	return concave_points

func scale_points_by_normals(points, edges, scaling_factor):

	var scaled_points = []
	var vertex_normals = find_vertex_normals(points, edges)
	
	# Iterate over each vertex and scale it by its corresponding vertex normal
	for i in range(points.size()):
		var scaled_point = points[i] + vertex_normals[i] * scaling_factor
		scaled_points.append(scaled_point)
	
	
	return scaled_points
	
func find_vertex_normals(points, edges):
	
	var vertex_normals = []
	var edge_normals = []

	
	#For each edge, find its normal
	for i in range(edges.size()):
		edge_normals.append(find_edge_normal(edges[i]))
	
	#ADDING THIS SO IT CALCULATES LAST EDGE NORMAL
	
	
	
	
	#Calculate vertex normal from adjacent edge normals
	for i in range(points.size()):
		var prev_index = (i - 1 + edges.size()) % edges.size()
		var prev_edge_normal = edge_normals[prev_index]
		var current_edge_normal
		
		
		if i == points.size()-1: 
			current_edge_normal = edge_normals[0]
		else:
			current_edge_normal = edge_normals[i]
		#
		var vertex_normal = prev_edge_normal + current_edge_normal
		
		vertex_normal = vertex_normal.normalized()
		vertex_normals.append(vertex_normal)
		
		#line(points[i], points[i] + vertex_normal)
		
	
	return vertex_normals
	
func find_edge_normal(edge):
	
	var start = edge[0]
	var end = edge[1]
	
	var direction = end - start
	var normal = Vector2(-direction.y, direction.x).normalized()
	#line(edge[0], edge[0] + normal)
	
	return normal

func sort_vertices_around_edge(edges: Array) -> Array:
	var vertices = []
	var unique_verts = {}
	
	# Extract unique vertices from edges
	for edge in edges:
		for vertex in edge:
			if vertex not in vertices:
				vertices.append(vertex)
	

	# Calculate center point (average of vertices)
	var center = Vector2(0, 0)
	for vertex in vertices:
		center += vertex
	center /= vertices.size()
	
	# Calculate angle from each point to center point
	var angles = {}
	for vertex in vertices:
		var angle = atan2(vertex.y - center.y, vertex.x - center.x)
		angles[vertex] = angle
	
	# Sort vertices based on angle
	vertices.sort_custom(func(v1, v2): return angles[v1] < angles[v2])
	
	return vertices

func sort_edges(sorted_vertices) -> Array:

	var sorted_edges = []

	# Iterate through each vertex
	for i in range(sorted_vertices.size()):
		# Get the current and next vertices
		var current_vertex = sorted_vertices[i]
		var next_index = (i + 1) % sorted_vertices.size()
		var next_vertex = sorted_vertices[next_index]
	
		# Create an edge using the current and next vertices
		var edge = [current_vertex, next_vertex]

		# Add the edge to the list of sorted edges
		sorted_edges.append(edge)
	
	return sorted_edges

func get_concave_triangles(concave_point, boundary_triangles):
	var concave_triangles = []

	#Check if point is in boundary triangle:
	for triangle in boundary_triangles:
		if triangle.has(concave_point):

			#Scratch everything below, i think we just remove the triangle at this point.
			concave_triangles.append(triangle)
			
			#polygon(triangle)
	
	
	return concave_triangles

func remove_triangle(triangles: Array, concave_triangles: Array, boundaries: Array) -> Array:
	
	#This function will run until 1 triangle is removed, then quit, so that boundaries can be recalculated.
	var ratio_threshold = 1.8
	
	#Find all edge lengths and find boundary edge of concave tri
	for triangle in concave_triangles:
		
		if triangle_was_erased: #If a triangle was erased, break from loop to not go onto next triangle
			break
		
		var edge_lengths = []
		var boundary_edge = null
		print('current_tri: ', triangle )
		
		# Find all edge lengths and identify boundary edge of the concave triangle
		for i in range(3):
			var edge = [triangle[i], triangle[(i + 1) % 3]]
			edge.sort()
			var edge_length = edge[0].distance_to(edge[1])
			edge_lengths.append(edge_length)
			
			if boundaries.has(edge):
				boundary_edge = edge

		if boundary_edge:
		
			# Calculate the lengths of the boundary edge and the other two edges
			var boundary_edge_length = boundary_edge[0].distance_to(boundary_edge[1])
			
			var other_edges = []
			for length in edge_lengths:
				if length != boundary_edge_length:
					other_edges.append(length)
					
			var other_edge_length_1 = other_edges[0]
			var other_edge_length_2 = other_edges[1]

			# Calculate the ratio
			var ratio_1 = boundary_edge_length / other_edge_length_1
			var ratio_2 = boundary_edge_length / other_edge_length_2
			print('ratio1: ', ratio_1, ', ratio2: ', ratio_2)
			
			# If either ratio exceeds the threshold, erase the triangle from triangles list
			if ratio_1 > ratio_threshold or ratio_2 > ratio_threshold:
				for tri in triangles:
					var triangle_array = PackedVector2Array(triangle)
					#Sort vertex arrays so that verticies will appear in same index for identical triangles
					tri.sort()
					triangle_array.sort()
					if tri == triangle_array:
						triangles.erase(triangle)
						print('removed triangle: ', triangle)
						triangle_was_erased = true
						break
					
			else:
				print('RATIO NOT EXCEEDED. Go to next concave triangle if it exists, or end the loop if not.')
			
			
	print('returning triangles')
	return triangles

			
			
			
		
		
		


#DEBUGGING
func line(a, b):
	var line = Line2D.new()
	line.points = PackedVector2Array([a * 50, b*50])
	line.width = 10
	
	UI.add_child(line)
	
	pass
	
func polygon(points):
	var scaled_points = PackedVector2Array()
	for point in points:
		scaled_points.append(point * 20)
	
	var poly = Polygon2D.new()
	poly.polygon = scaled_points
	
	UI.add_child(poly)
	pass

func _on_button_pressed():
	generate_borders()
	pass # Replace with function body.
