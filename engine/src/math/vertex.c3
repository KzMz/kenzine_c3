module kenzine::math;

import std::math::vector;
import kenzine::common;
import kenzine::utils;

distinct Index = uint;

enum VertexFormat
{
	FLOAT32_2,
	FLOAT32_3,
	FLOAT32_4,
}

struct Vertex3d
{
	Vec3f position;
	Color4f color;
}

struct Vertex2d
{
	Vec2f position;
	Color4f color;
}

fn VertexFormat[] vertex2d_formats()
{
	return 
	{
		VertexFormat.FLOAT32_2,
		VertexFormat.FLOAT32_4,
	};
}

fn VertexFormat[] vertex3d_formats()
{
	return 
	{
		VertexFormat.FLOAT32_3,
		VertexFormat.FLOAT32_4,
	};
}

macro vertex2d_attribute_format(usz index)
{
	return vertex2d_formats()[index];
}

macro vertex3d_attribute_format(usz index)
{
	return vertex3d_formats()[index];
}

macro vertex2d_attribute_count()
{
	return Vertex2d.membersof.len;
}

macro vertex3d_attribute_count()
{
	return Vertex3d.membersof.len;
}

macro vertex2d_attribute_offset(usz index)
{
	return utils::offset_of_index(Vertex2d, index);
}

macro vertex3d_attribute_offset(usz index)
{
	return utils::offset_of_index(Vertex3d, index);
}