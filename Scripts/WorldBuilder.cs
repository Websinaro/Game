using Godot;

public partial class WorldBuilder : Node3D
{
    public override void _Ready()
    {
        ConfigureInput();
        BuildLighting();
        BuildGround();
        BuildRoad();
        BuildVillage();
        BuildPlayer();
    }

    private void BuildLighting()
    {
        var sun = new DirectionalLight3D();
        sun.Name = "KeralaSun";
        sun.RotationDegrees = new Vector3(-48f, -32f, 0f);
        sun.LightEnergy = 1.15f;
        sun.ShadowEnabled = true;
        AddChild(sun);

        var environment = new WorldEnvironment();
        var env = new Environment();
        env.BackgroundMode = Environment.BGMode.Color;
        env.BackgroundColor = new Color(0.52f, 0.76f, 0.91f);
        env.AmbientLightSource = Environment.AmbientSource.Color;
        env.AmbientLightColor = new Color(0.72f, 0.78f, 0.70f);
        env.AmbientLightEnergy = 0.7f;
        environment.Environment = env;
        AddChild(environment);
    }

    private void BuildGround()
    {
        var ground = new StaticBody3D { Name = "Ground" };
        var mesh = new BoxMesh
        {
            Size = new Vector3(120f, 1f, 120f),
            Material = MakeMaterial(new Color(0.25f, 0.48f, 0.22f))
        };
        var visual = new MeshInstance3D { Mesh = mesh, Position = new Vector3(0f, -0.5f, 0f) };
        ground.AddChild(visual);

        var collision = new CollisionShape3D
        {
            Shape = new BoxShape3D { Size = new Vector3(120f, 1f, 120f) },
            Position = new Vector3(0f, -0.5f, 0f)
        };
        ground.AddChild(collision);
        AddChild(ground);
    }

    private void BuildRoad()
    {
        AddBox("VillageRoad", new Vector3(4.5f, 0.12f, 100f),
            new Vector3(0f, 0.06f, 0f), new Color(0.16f, 0.17f, 0.16f));
        AddBox("RoadEdgeLeft", new Vector3(0.18f, 0.16f, 100f),
            new Vector3(-2.35f, 0.08f, 0f), new Color(0.72f, 0.67f, 0.53f));
        AddBox("RoadEdgeRight", new Vector3(0.18f, 0.16f, 100f),
            new Vector3(2.35f, 0.08f, 0f), new Color(0.72f, 0.67f, 0.53f));
    }

    private void BuildVillage()
    {
        // Simple placeholder buildings; replace these with Prisma3D GLB models later.
        BuildHouse(new Vector3(-8f, 0f, -9f), new Color(0.88f, 0.77f, 0.58f));
        BuildHouse(new Vector3(8f, 0f, 8f), new Color(0.83f, 0.86f, 0.72f));
        BuildHouse(new Vector3(-10f, 0f, 18f), new Color(0.78f, 0.82f, 0.74f));

        Vector3[] treePositions =
        {
            new(-7f, 0f, -22f), new(7f, 0f, -19f), new(-12f, 0f, -2f),
            new(12f, 0f, -5f), new(-8f, 0f, 12f), new(9f, 0f, 23f),
            new(-16f, 0f, 29f), new(16f, 0f, 32f), new(-20f, 0f, -20f),
            new(20f, 0f, -25f)
        };

        foreach (var position in treePositions)
            BuildCoconutTree(position);
    }

    private void BuildHouse(Vector3 position, Color wallColor)
    {
        AddBox("HouseBody", new Vector3(5f, 3f, 4f),
            position + new Vector3(0f, 1.5f, 0f), wallColor);

        // Two sloping roof halves are approximated with rotated boxes for the prototype.
        AddBox("RoofLeft", new Vector3(3.1f, 0.28f, 4.8f),
            position + new Vector3(-0.78f, 3.2f, 0f),
            new Color(0.42f, 0.16f, 0.10f), new Vector3(0f, 0f, -24f));
        AddBox("RoofRight", new Vector3(3.1f, 0.28f, 4.8f),
            position + new Vector3(0.78f, 3.2f, 0f),
            new Color(0.48f, 0.19f, 0.11f), new Vector3(0f, 0f, 24f));
        AddBox("Door", new Vector3(0.9f, 1.8f, 0.12f),
            position + new Vector3(0f, 0.9f, -2.06f), new Color(0.25f, 0.13f, 0.07f));
    }

    private void BuildCoconutTree(Vector3 position)
    {
        AddCylinder("PalmTrunk", 0.22f, 5.5f,
            position + new Vector3(0f, 2.75f, 0f), new Color(0.38f, 0.23f, 0.12f));

        // Temporary green crown. Prisma3D palm models will replace this.
        AddSphere("PalmCrown", 1.65f,
            position + new Vector3(0f, 5.5f, 0f), new Color(0.10f, 0.38f, 0.13f));
        for (int i = 0; i < 5; i++)
        {
            float angle = Mathf.Tau * i / 5f;
            Vector3 offset = new Vector3(Mathf.Cos(angle) * 1.15f, 0.1f,
                Mathf.Sin(angle) * 1.15f);
            AddBox("PalmFrond", new Vector3(2.8f, 0.10f, 0.32f),
                position + new Vector3(0f, 5.6f, 0f) + offset,
                new Color(0.12f, 0.34f, 0.10f),
                new Vector3(0f, -Mathf.RadToDeg(angle), -12f));
        }
    }

    private void BuildPlayer()
    {
        var playerScene = GD.Load<PackedScene>("res://Scenes/Player.tscn");
        var player = playerScene.Instantiate<CharacterBody3D>();
        player.Position = new Vector3(0f, 1.2f, 5f);
        AddChild(player);
    }

    private void ConfigureInput()
    {
        AddKeyAction("move_left", Key.A, Key.Left);
        AddKeyAction("move_right", Key.D, Key.Right);
        AddKeyAction("move_forward", Key.W, Key.Up);
        AddKeyAction("move_back", Key.S, Key.Down);
        AddKeyAction("jump", Key.Space);
    }

    private static void AddKeyAction(string actionName, params Key[] keys)
    {
        if (!InputMap.HasAction(actionName))
            InputMap.AddAction(actionName);

        foreach (Key key in keys)
        {
            var keyEvent = new InputEventKey { PhysicalKeycode = key };
            InputMap.ActionAddEvent(actionName, keyEvent);
        }
    }

    private void AddBox(string name, Vector3 size, Vector3 position, Color color,
        Vector3? rotationDegrees = null)
    {
        var mesh = new BoxMesh { Size = size, Material = MakeMaterial(color) };
        var instance = new MeshInstance3D
        {
            Name = name,
            Mesh = mesh,
            Position = position,
            RotationDegrees = rotationDegrees ?? Vector3.Zero
        };
        AddChild(instance);
    }

    private void AddCylinder(string name, float radius, float height, Vector3 position, Color color)
    {
        var instance = new MeshInstance3D
        {
            Name = name,
            Mesh = new CylinderMesh
            {
                TopRadius = radius * 0.72f,
                BottomRadius = radius,
                Height = height,
                Material = MakeMaterial(color)
            },
            Position = position
        };
        AddChild(instance);
    }

    private void AddSphere(string name, float radius, Vector3 position, Color color)
    {
        var instance = new MeshInstance3D
        {
            Name = name,
            Mesh = new SphereMesh { Radius = radius, Height = radius * 2f, Material = MakeMaterial(color) },
            Position = position
        };
        AddChild(instance);
    }

    private static StandardMaterial3D MakeMaterial(Color color)
    {
        return new StandardMaterial3D { AlbedoColor = color, Roughness = 0.92f };
    }
}
