AddCSLuaFile()

function caveCenterDist(x, y)
	return math.sqrt(math.pow(x, 2) + math.pow(y, 2))
end

local mathClamp = math.Clamp

function caveChunkTriangles(heights, chunkX, chunkY)
	local sx, sy = caveChunkSize / caveResX, caveChunkSize / caveResY
	local cx, cy = chunkX * caveChunkSize, chunkY * caveChunkSize
	local Vector = Vector
	local lc = Vector(-0.5 * caveChunkSize, -0.5 * caveChunkSize, 0)
	local VAdd = lc.Add
	local triangles, trianglesLen = {}, 0
	local normals = {}
	local mathClamp = mathClamp

	for y = 0, #heights - 1 do
		for x = 0, #heights[y] - 1 do
			local h1, h2, h3, h4 = heights[y][x], heights[y + 1][x], heights[y][x + 1], heights[y + 1][x + 1]
			local p1 = Vector((x - 1) * sx, (y - 1) * sy, h1)
			local p2 = Vector((x - 1) * sx, y * sy, h2)
			local p3 = Vector(x * sx, (y - 1) * sy, h3)
			local p4 = Vector(x * sx, y * sy, h4)
			local p5 = Vector((x - 1) * sx, (y - 1) * sy, h1)
			local p6 = Vector((x - 1) * sx, y * sy, h2)
			local p7 = Vector(x * sx, (y - 1) * sy, h3)
			local p8 = Vector(x * sx, y * sy, h4)
			VAdd(p1, lc)
			VAdd(p2, lc)
			VAdd(p3, lc)
			VAdd(p4, lc)
			VAdd(p5, lc)
			VAdd(p6, lc)
			VAdd(p7, lc)
			VAdd(p8, lc)
			p5[3] = p5[3] + mathClamp(caveMapSize / 2 - caveCenterDist(cx + p5[1], cy + p5[2]), 0, caveMaxCeil)
			p6[3] = p6[3] + mathClamp(caveMapSize / 2 - caveCenterDist(cx + p6[1], cy + p6[2]), 0, caveMaxCeil)
			p7[3] = p7[3] + mathClamp(caveMapSize / 2 - caveCenterDist(cx + p7[1], cy + p7[2]), 0, caveMaxCeil)
			p8[3] = p8[3] + mathClamp(caveMapSize / 2 - caveCenterDist(cx + p8[1], cy + p8[2]), 0, caveMaxCeil)

			if not (p1[3] == p5[3] and p2[3] == p6[3] and p3[3] == p7[3] and p4[3] == p8[3]) then
				local n1 = (p3 - p2):Cross(p2 - p1)
				n1:Normalize()
				n1:Div(4)
				local n2 = (p4 - p2):Cross(p2 - p3)
				n1:Normalize()
				n1:Div(4)
				normals[y], normals[y + 1] = normals[y] or {}, normals[y + 1] or {}
				normals[y][x], normals[y + 1][x], normals[y][x + 1], normals[y + 1][x + 1] = normals[y][x] or Vector(), normals[y + 1][x] or Vector(), normals[y][x + 1] or Vector(), normals[y + 1][x + 1] or Vector()
				normals[y][x] = normals[y][x] + n1
				normals[y + 1][x] = normals[y + 1][x] + n1 + n2
				normals[y][x + 1] = normals[y][x + 1] + n1 + n2
				normals[y + 1][x + 1] = normals[y + 1][x + 1] + n2

				if x > 0 and y > 0 and x < #heights - 1 and y < #heights[x] - 1 then
					local k = trianglesLen

					triangles[trianglesLen + 1] = {
						x, y, pos = p1,
					}

					triangles[trianglesLen + 2] = {
						x, y + 1, pos = p2,
					}

					triangles[trianglesLen + 3] = {
						x + 1, y, pos = p3,
					}

					triangles[trianglesLen + 4] = {
						x + 1, y, pos = p3,
					}

					triangles[trianglesLen + 5] = {
						x, y + 1, pos = p2,
					}

					triangles[trianglesLen + 6] = {
						x + 1, y + 1, pos = p4,
					}

					triangles[trianglesLen + 7] = {
						x, y, true, pos = p5,
					}

					triangles[trianglesLen + 8] = {
						x + 1, y, true, pos = p7,
					}

					triangles[trianglesLen + 9] = {
						x, y + 1, true, pos = p6,
					}

					triangles[trianglesLen + 10] = {
						x + 1, y, true, pos = p7,
					}

					triangles[trianglesLen + 11] = {
						x + 1, y + 1, true, pos = p8,
					}

					triangles[trianglesLen + 12] = {
						x, y + 1, true, pos = p6,
					}

					trianglesLen = trianglesLen + 12
				end
			end
		end
	end

	for k = 1, trianglesLen do
		local vertex = triangles[k]
		vertex.normal = normals[vertex[2]][vertex[1]]

		if vertex[3] then
			vertex.normal = -vertex.normal
		end

		vertex.u, vertex.v = vertex[1] * caveTextureTile, vertex[2] * caveTextureTile
	end

	return triangles
end

function caveHeightAtPoint(s, x, y)
	local nx, ny = s + x * caveNoiseScale, y * caveNoiseScale
	local perlinNoise = perlinNoise

	return perlinNoise(nx * 0.5, ny * 0.5) * caveMaxH + perlinNoise(nx * 2, ny * 2) * caveMaxH / 2 + perlinNoise(nx * 6, ny * 6) * caveMaxH / 8
end

function caveNoiseChunk(s, dx, dy)
	local t = {}

	for y = 0, caveResY + 2 do
		t[y] = {}

		for x = 0, caveResX + 2 do
			t[y][x] = caveHeightAtPoint(s, (x - 1) / caveResX + dx - 0.5, (y - 1) / caveResY + dy - 0.5)
		end
	end

	return t
end