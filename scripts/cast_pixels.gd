extends RefCounted
## Code-native, limited-palette upper bodies for the seven later-chapter roles.
## Each is one connected 20 x 40 texture bound to the existing continuous mesh.
static var textures: Dictionary = {}
const CLOTH = {1:"555057",3:"405958",4:"ab843e",5:"324360",9:"775568",10:"6b704b",11:"959085"}

static func paint(im: Image, r: Rect2i, hex: String) -> void:
	im.fill_rect(r,Color(hex))

static func get_body(id: int) -> Texture2D:
	if textures.has(id): return textures[id]
	var im:=Image.create(20,40,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
	var coat: String=CLOTH[id]
	var hair: String="959085" if id in [1,3,9] else "171f27"
	paint(im,Rect2i(5,2,10,12),"d9a56c")
	paint(im,Rect2i(8,5,7,8),"efc58d")
	paint(im,Rect2i(15,8,2,3),"d9a56c")
	paint(im,Rect2i(9,12,5,6),"d9a56c")
	paint(im,Rect2i(4,0,11,5),hair);paint(im,Rect2i(4,4,3,6),hair)
	paint(im,Rect2i(13,6,1,2),"171f27")
	paint(im,Rect2i(14,11,2,1),"a67650")
	paint(im,Rect2i(3,16,14,24),coat)
	paint(im,Rect2i(5,14,4,5),coat);paint(im,Rect2i(13,14,3,5),coat)
	paint(im,Rect2i(3,19,3,21),"2b383e")
	paint(im,Rect2i(10,18,2,22),"37333c")
	paint(im,Rect2i(9,17,4,4),"e9dbb2")
	match id:
		1:
			paint(im,Rect2i(7,1,7,2),"e9dbb2");paint(im,Rect2i(11,7,5,1),"555057")
			paint(im,Rect2i(11,21,1,14),"ab843e");paint(im,Rect2i(12,28,4,2),"959085")
		3:
			paint(im,Rect2i(2,3,4,6),"959085");paint(im,Rect2i(12,25,4,6),"e9dbb2")
			paint(im,Rect2i(7,22,1,2),"959085");paint(im,Rect2i(7,28,1,2),"959085")
		4:
			paint(im,Rect2i(3,1,13,4),"70532c");paint(im,Rect2i(11,4,7,2),"ab843e")
			paint(im,Rect2i(6,17,2,23),"324360");paint(im,Rect2i(5,28,10,10),"324360")
		5:
			paint(im,Rect2i(5,0,10,3),"171f27");paint(im,Rect2i(10,19,2,9),"70532c")
			paint(im,Rect2i(12,23,4,1),"ab843e")
		9:
			paint(im,Rect2i(3,1,13,4),"e9dbb2");paint(im,Rect2i(1,22,3,18),coat)
			paint(im,Rect2i(7,17,3,17),"623638");paint(im,Rect2i(9,17,4,3),"985442")
		10:
			paint(im,Rect2i(3,0,10,5),"171f27");paint(im,Rect2i(6,18,3,5),"ab843e")
			paint(im,Rect2i(13,27,3,7),"70532c")
		11:
			paint(im,Rect2i(4,0,13,4),"171f27");paint(im,Rect2i(12,18,1,11),"985442")
			paint(im,Rect2i(11,28,3,5),"985442");paint(im,Rect2i(12,29,1,2),"e9dbb2")
	textures[id]=ImageTexture.create_from_image(im);return textures[id]
