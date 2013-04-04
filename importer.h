#include <fbxsdk.h>
#include <stdio.h>
#include <iostream>
#include <vector>
#include <D3D10.h>
#include <D3DX10.h>
#include <D3Dcompiler.h>
#include <xnamath.h>
#include <direct.h>
using namespace std;

struct Vertex
{
	D3DXVECTOR3 Pos;
	D3DXVECTOR3 Normal;
	D3DXVECTOR2 Tex;
	int 		texNum;
};

int Import( char* filename, vector<Vertex>* vert );
void LoadScene(char* filename);
void ProcessScene();
void ProcessNode( FbxNode* node, int attributeType);
void ProcessMesh( FbxNode* node );
FbxVector2 GetTexCoords( FbxMesh* mesh, int layerIndex, int polygonIndex, int polygonVertexIndex, int vertexIndex );