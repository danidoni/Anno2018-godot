extends Node

const SIZE = 2048
const DEBUG = 1

var current_heights = []
var current_x = 0
var data = PoolByteArray()
var path = null
var images = []
var c = 0

func begin(output_path):
	path = output_path
	c = 0
	_reset()

func _reset():
	current_x = 0
	images = []
	current_heights = []
	for i in range(SIZE):
		current_heights.append(0)
	data = PoolByteArray()
	data.resize(SIZE * SIZE * 4)
	for i in range(data.size()):
		data[i] = 0

func add_image(id, width, height, data):
	assert(width <= SIZE)
	assert(height <= SIZE)
	if current_x + width > SIZE:
		current_x = 0
	
	var max_height = 0
	for i in range(current_x, current_x + width):
		max_height = max(max_height, current_heights[i])
	
	if max_height + height > SIZE:
		return [false, []]
	
	assert(max_height + height <= SIZE)
	
	var x = current_x
	var y = max_height
	
	images.append({
		'id': id,
		'pos': Vector2(x, y),
		'size': Vector2(width, height),
	})
	
	_add_image_data(x, y, width, height, data)
	
	for i in range(current_x, current_x + width):
		current_heights[i] = max_height + height
	
	current_x += width
	
	return [true, Vector2(x, y)]

func save():
	var image = Image.new()
	image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, data)
	# image.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC, 1.0)
	if DEBUG:
		assert(image.save_png(path + "_" + str(c) + ".png") == OK)
	
	var image_texture = ImageTexture.new()
	var image_texture_path = path + "_" + str(c) + ".tres"
	image_texture.storage = ImageTexture.STORAGE_COMPRESS_LOSSLESS
	image_texture.create_from_image(image, Texture.FLAG_MIPMAPS)
	assert(ResourceSaver.save(image_texture_path, image_texture, ResourceSaver.FLAG_COMPRESS) == OK)
	
	# There currently is a bug in Godot, where the saved resource has incorrectly
	# set "image = null", when it should be "image = SubResource ( 1 ).
	# https://github.com/godotengine/godot/issues/18801
	var tmp = File.new()
	assert(OK == tmp.open(image_texture_path, File.READ_WRITE))
	tmp.seek_end()
	tmp.store_line("image = SubResource( 1 )")
	tmp.close()
	
	# Now reload the texture from disk. This is necessary, otherwise it is 
	# copied into every single AtlasTexture below.
	image_texture = load(image_texture_path)
	
	for image in images:
		var atlas_texture = AtlasTexture.new()
		atlas_texture.filter_clip = true
		atlas_texture.region = Rect2(image['pos'], image['size'])
		atlas_texture.atlas = image_texture
		
		assert(ResourceSaver.save(path + "/" + image['id'] + ".res", atlas_texture) == OK)
	
	c += 1
	_reset()


func _add_image_data(x_pos, y_pos, width, height, pixels):
	var j = 0
	for y in height:
		for x in width:
			var idx = (x_pos + x + SIZE * y + SIZE * y_pos) * 4
			data[idx + 0] = pixels[j * 4 + 0]
			data[idx + 1] = pixels[j * 4 + 1]
			data[idx + 2] = pixels[j * 4 + 2]
			data[idx + 3] = pixels[j * 4 + 3]
			j += 1