//------------------------------------------------------------------------
//
//  Visibility Buffer
//
//  Copyright (C) 2009 Andrew Apted
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//------------------------------------------------------------------------


// map data
#define V_BOTTOM  0x0001
#define V_LEFT    0x0002 


// vis results
#define V_BASIC   0x0010   // ultra basic
#define V_SPAN    0x0020   // long spans
#define V_LSHAPE  0x0040   // L shape testing
#define V_WONKA   0x0080   // Wonka's (et al) method


struct Stair_Pos
{
	short x, y, side;
};

typedef std::vector<Stair_Pos> Stair_Steps;


class Vis_Buffer
{
private:
	int W, H;  // size

	short * data;

	// square we are processing
	int loc_x, loc_y;

	// current transform
	int flip_x, flip_y;

public:
	Vis_Buffer(int width, int height) :
    	W(width), H(height), flip_x(0), flip_y(0)
	{
		data = new short[W * H];

		Clear();
	}

	~Vis_Buffer()
	{
		delete[] data;
	}

public:
	inline int Trans_X(int x)
	{
		return flip_x ? (loc_x * 2 - x) : x;
	}

	inline int Trans_Y(int y)
	{
		return flip_y ? (loc_y * 2 - y) : y;
	}

	inline int Trans_Side(int side)
	{
		if ( (flip_x && (side == 4 || side == 6)) ||
		     (flip_y && (side == 2 || side == 8)) )
		{
			return 10 - side;
		}
		return side;
	}

	inline bool isValid(int x, int y)
	{
		x = Trans_X(x);
		y = Trans_Y(y);

		return (0 <= x && x < W) && (0 <= y && y < H);
	}

	inline short& at(int x, int y)
	{
		x = Trans_X(x);
		y = Trans_Y(y);

		return data[y * W + x];
	}

	void Clear()
	{
		memset(data, 0, sizeof(short) * W * H);
	}

	void AddWall(int x, int y, int side)
	{
		if (side == 6)
		{
			x++; side = 4;
		}

		if (side == 8)
		{
			y++; side = 2;
		}

		if (! isValid(x, y))
			return;

		if (side == 2)
			at(x, y) |= V_BOTTOM;
		else
			at(x, y) |= V_LEFT;
	}

	bool TestWall(int x, int y, int side)
	{
		side = Trans_Side(side);

		if (side == 6)
		{
			if (flip_x) x--; else x++;
			side = 4;
		}

		if (side == 8)
		{
			if (flip_y) y--; else y++;
			side = 2;
		}

		if (! isValid(x, y))
			return true;

		if (side == 2)
			return (at(x, y) & V_BOTTOM) ? true : false;
		else
			return (at(x, y) & V_LEFT) ? true : false;
	}

	void ReadMap(const char *filename)
	{
		FILE *fp = fopen(filename, "r");
		if (! fp)
			FatalError("No such file: %s\n", filename);

		int x, y, side;

		while (fscanf(fp, " %d %d %d ", &x, &y, &side) == 3)
		{
			AddWall(x, y, side);
		}

		fclose(fp);
	}

private:
	void DoBasic(int dx, int dy, int side)
	{
		int x = loc_x;
		int y = loc_y;

		for (;;)
		{
			if (! isValid(x, y))
				return;

			if (TestWall(x, y, side))
				break;

			x += dx; y += dy;
		}

		for (;;)
		{
			x += dx; y += dy;

			if (! isValid(x, y))
				return;

			at(x, y) |= V_BASIC;
		}
	}

	void AddStep(Stair_Steps& dest, int x, int y, int side)
	{
		Stair_Pos pos;

		pos.x = x;
		pos.y = y;
		pos.side = side;

		dest.push_back(pos);
	}

	void CopySteps(Stair_Steps& dest, const Stair_Steps& src)
	{
		for (unsigned int i = 0; i < src.size(); i++)
			dest.push_back(src[i]);
	}

	void MarkSteps(const Stair_Steps& steps)
	{
		if (steps.size() < 2)
			return;

		// determine bounding box
		int lx = steps.front().x;
		int ly = steps.back().y;

		int ww = steps.back().x  - lx;
		int hh = steps.front().y - ly;

		if (steps.back().side == 2)
			ww++;

		if (steps.front().side == 4)
			hh++;

		// skip if too small
		if (lx > loc_x && ww <= 1 && ly > loc_y && hh <= 1)
			return;

		// fill in the "gaps" inside the bbox (behind the stair-step)
		for (unsigned int i = 0; i < steps.size(); i++)
		{
			if (steps[i].side == 4)
				for (int sx = steps[i].x; sx < lx+ww; sx++)
					at(sx, steps[i].y) |= V_LSHAPE;
		}

		// normal case : mark all squares in the quadrant which lie
		// in the shadow area cast by the stair-step's bounding box.

		double tx = lx - loc_x;
		double ty = ly - loc_y + hh - 1;

		double bx = lx - loc_x + ww - 1;
		double by = ly - loc_y;

		if (bx == 0 && ly > loc_y) return;

		for (int ny = loc_y; ny < loc_y+H; ny++)
		for (int nx = loc_x; nx < loc_x+W; nx++)
		{
			if (! isValid(loc_x, ny))
				return;
			if (! isValid(nx, ny))
				break;

			if (nx >= lx+ww || ny >= ly+hh)
			{
				bool tl = true;
				bool br = true;
  
				if (lx > loc_x)
				{
					assert(tx > 0);
					double z = loc_y + 1 + (nx - loc_x) * ty / tx;

					if (ny+1 > z)
						tl = false;
				}

  				if (ly > loc_y)
				{
					assert(bx > 0);
					double z = loc_y + (nx - loc_x) * by / bx;

					if (ny < z)
						br = false;
				}

				if (tl && br)
					at(nx, ny) |= V_SPAN;
			}
		}
	}

	void FollowStair(Stair_Steps& steps, int sx, int sy, int side)
	{
		AddStep(steps, sx, sy, side);

		for (;;)
		{
			if (side == 2)
			{
				sx++;
				if (! isValid(sx, sy)) break;

				bool go_right = TestWall(sx, sy, 2);
				bool go_down  = (sy-1 >= loc_y) && TestWall(sx, sy-1, 4);

				// handle branches with recursion
				if (go_right && go_down)
				{
					Stair_Steps other;
					CopySteps(other, steps);

					FollowStair(other, sx, sy, 2);
					go_right = false;
				}

				if (go_right)
				{
					// OK
				}
				else if (go_down)
				{
					sy--;  // OK
					side = 4;
				}
				else
					break;
			}
			else
			{
				assert(side == 4);

				if (sy <= loc_y) break;

				bool go_right = TestWall(sx, sy, 2);
				bool go_down  = (sy-1 >= loc_y) && TestWall(sx, sy-1, 4);

				// handle branches with recursion
				if (go_right && go_down)
				{
					// recursive bit
					Stair_Steps other;
					CopySteps(other, steps);

					FollowStair(other, sx, sy, 2);
					go_right = false;
				}

				if (go_right)
				{
					side = 2;
				}
				else if (go_down)
				{
					sy--;  // OK
				}
				else
					break;
			}

			AddStep(steps, sx, sy, side);
		}

		MarkSteps(steps);
	}

	void DoSteps(int quadrant)
	{
		flip_x = (quadrant & 1);
		flip_y = (quadrant & 2);

		for (int dy = 0; dy < H; dy++)
		for (int dx = 0; dx < W; dx++)
		{
			int sx = loc_x + dx;
			int sy = loc_y + dy;

			if (! isValid(loc_x, sy))
				return;
			if (! isValid(sx, sy))
				break;

			if (  (dy > 0 && TestWall(sx, sy, 2)) &&
			    ! (dx > 0 && TestWall(sx-1, sy, 2)) &&
				! (dx > 0 && TestWall(sx, sy, 4)) )
			{
				Stair_Steps base;
				FollowStair(base, sx, sy, 2);
			}

			if (  (dx > 0 && TestWall(sx, sy, 4)) &&
			    ! (          TestWall(sx-1, sy, 8)) &&
				! (isValid(sx, sy+1) && TestWall(sx, sy+1, 4)) )
			{
				Stair_Steps base;
				FollowStair(base, sx, sy, 4);
			}

		}
	}

public:
	void ClearVis()
	{
		int len = W * H;

		for (int i = 0; i < len; i++)
			data[i] &= 7;
	}

	void ProcessVis(int x, int y)
	{
		loc_x = x;
		loc_y = y;

//		DoBasic(-1, 0, 4); DoBasic(0, -1, 2);
//		DoBasic(+1, 0, 6); DoBasic(0, +1, 8);

		DoSteps(0);
		DoSteps(1);
		DoSteps(2);
		DoSteps(3);

		flip_x = flip_y = 0;
	}

	int GetVis(int x, int y)
	{
		short d = at(x, y);

  		if (d & V_BASIC)  return 1;
		if (d & V_LSHAPE) return 3;
		if (d & V_SPAN)   return 2;
		if (d & V_WONKA)  return 4;

		return 0;
	}
};


//--- editor settings ---
// vi:ts=4:sw=4:noexpandtab
