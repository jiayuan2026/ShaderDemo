
using UnityEngine;
using System.Collections.Generic;

public class CubeLevelGenerator : MonoBehaviour
{
    [Header("Level Settings")]
    public GameObject cubePrefab;

    public int width = 5;
    public int height = 3;
    public int depth = 5;

    [Range(0f, 1f)]
    public float spawnProbability = 0.65f;

    public float spacing = 1.1f;

    [Header("Random Seed")]
    public int seed = 12345;

    private List<GameObject> spawnedCubes = new();

    void Start()
    {
        GenerateLevel();
    }

    public void GenerateLevel()
    {
        ClearLevel();

        Random.InitState(seed);

        for (int x = 0; x < width; x++)
        {
            for (int y = 0; y < height; y++)
            {
                for (int z = 0; z < depth; z++)
                {
                    if (Random.value > spawnProbability)
                        continue;

                    Vector3 position = new Vector3(
                        x * spacing,
                        y * spacing,
                        z * spacing
                    );

                    GameObject cube = Instantiate(
                        cubePrefab,
                        position,
                        Quaternion.identity,
                        transform
                    );

                    spawnedCubes.Add(cube);
                }
            }
        }
    }

    public void ClearLevel()
    {
        foreach (GameObject cube in spawnedCubes)
        {
            if (cube != null)
                Destroy(cube);
        }

        spawnedCubes.Clear();
    }
}

