module kenzine::math;
import std::math::vector;

distinct Index = usz;

enum VertexFormat
{
	FLOAT32_2,
	FLOAT32_3,
}

struct Vertex3d
{
	Vec3f position;
}

struct Vertex2d
{
	Vec2f position;
}

fn VertexFormat[] vertex2d_formats()
{
	return 
	{
		VertexFormat.FLOAT32_2,
	};
}

fn VertexFormat[] vertex3d_formats()
{
	return 
	{
		VertexFormat.FLOAT32_3,
	};
}