using Godot;

public partial class Main : Node3D
{
    private readonly Color grass = new Color(0.22f, 0.48f, 0.22f);
    private readonly Color road = new Color(0.16f, 0.17f, 0.18f);

    public override void _Ready()
    {
        CreateLighting();
        CreateGroundAndRoad();
        CreateVillageHouses();
        CreateCoconutTrees();
        CreatePlayer();
        CreateMobileControls();
    }

    private void CreateLighting()
    {
        var sun = new DirectionalLight3D();
        sun.RotationDegrees = new Vector3(-48, -28, 0);
        sun.LightEnergy = 1.15f;
        AddChild(sun);

        var environment = new WorldEnvironment();
        var env = new Environment();
        env.BackgroundMode = Environment.BGMode.Color;
        env.BackgroundColor = new Color(0.55f, 0.78f, 0.92f);
        environment.Environment = env;
        AddChild(environment);
    }

    private void CreateGroundAndRoad()
    {
        CreateBox("Ground", new Vector3(0, -0.4f, 0),
            new Vector3(120, 0.8f, 120), grass, true);

        CreateBox("VillageRoad", new Vector3(0, 0.02f, 0),
            new Vector3(7, 0.12f, 110), road, true);

        // Pale road edges make the first prototype easier to read.
        CreateBox("RoadEdgeLeft", new Vector3(-3.65f, 0.04f, 0),
            new Vector3(0.18f, 0.14f, 110), new Color(0.72f, 0.68f, 0.55f), false);
        CreateBox("RoadEdgeRight", new Vector3(3.65f, 0.04f, 0),
            new Vector3(0.18f, 0.14f, 110), new Color(0.72f, 0.68f, 0.55f), false);
    }

    private void CreateVillageHouses()
    {
        CreateHouse(new Vector3(-10, 0, -13), new Color(0.83f, 0.70f, 0.49f));
        CreateHouse(new Vector3(11, 0, 4), new Color(0.78f, 0.80f, 0.70f));
        CreateHouse(new Vector3(-12, 0, 25), new Color(0.88f, 0.78f, 0.60f));
        CreateHouse(new Vector3(12, 0, -35), new Color(0.78f, 0.72f, 0.62f));
    }

    private void CreateHouse(Vector3 position, Color wallColor)
    {
        // Temporary blockout house. All pieces are placed in world coordinates.
        CreateBox("HouseBody", position + new Vector3(0, 2, 0),
            new Vector3(7, 4, 6), wallColor, true);

        CreateBox("Roof", position + new Vector3(0, 4.35f, 0),
            new Vector3(8, 0.55f, 7), new Color(0.42f, 0.16f, 0.11f), false);

        CreateBox("Door", position + new Vector3(0, 1.15f, -3.06f),
            new Vector3(1.25f, 2.3f, 0.12f), new Color(0.28f, 0.15f, 0.08f), false);
    }

    private void CreateCoconutTrees()
    {
        Vector3[] positions =
        {
            new Vector3(-7, 0, -27), new Vector3(8, 0, -22),
            new Vector3(-17, 0, -2), new Vector3(18, 0, 17),
            new Vector3(-8, 0, 39), new Vector3(7, 0, 43),
            new Vector3(-23, 0, 18), new Vector3(23, 0, -15),
            new Vector3(-19, 0, -43), new Vector3(18, 0, 37)
        };

        foreach (var position in positions)
        {
            var tree = new Node3D();
            tree.Name = "CoconutTree";
            tree.Position = position;
            AddChild(tree);

            var trunkMesh = new CylinderMesh();
            trunkMesh.TopRadius = 0.18f;
            trunkMesh.BottomRadius = 0.32f;
            trunkMesh.Height = 6.5f;
            var trunk = new MeshInstance3D();
            trunk.Mesh = trunkMesh;
            trunk.Position = new Vector3(0, 3.25f, 0);
            trunk.MaterialOverride = Material(new Color(0.38f, 0.22f, 0.11f));
            tree.AddChild(trunk);

            for (int i = 0; i < 6; i++)
            {
                var leafMesh = new SphereMesh();
                leafMesh.Radius = 1.0f;
                leafMesh.Height = 0.45f;
                var leaf = new MeshInstance3D();
                leaf.Mesh = leafMesh;
                leaf.Scale = new Vector3(1.6f, 0.45f, 0.65f);
                float angle = i * Mathf.Tau / 6.0f;
                leaf.Position = new Vector3(Mathf.Cos(angle) * 1.05f, 6.45f, Mathf.Sin(angle) * 1.05f);
                leaf.RotationDegrees = new Vector3(0, Mathf.RadToDeg(angle), -18);
                leaf.MaterialOverride = Material(new Color(0.10f, 0.38f, 0.12f));
                tree.AddChild(leaf);
            }
        }
    }

    private void CreatePlayer()
    {
        var playerScene = GD.Load<PackedScene>("res://Scenes/Player.tscn");
        var player = playerScene.Instantiate<CharacterBody3D>();
        player.Name = "Player";
        player.Position = new Vector3(0, 1.2f, 12);
        AddChild(player);
    }

    private void CreateMobileControls()
    {
        var layer = new CanvasLayer();
        AddChild(layer);

        AddTouchButton(layer, "↑", "move_forward", new Vector2(112, -178));
        AddTouchButton(layer, "↓", "move_back", new Vector2(112, -78));
        AddTouchButton(layer, "←", "move_left", new Vector2(12, -78));
        AddTouchButton(layer, "→", "move_right", new Vector2(212, -78));

        var hint = new Label();
        hint.Text = "KERALA VILLAGE  •  Prototype 01";
        hint.Position = new Vector2(18, 16);
        hint.AddThemeColorOverride("font_color", Colors.White);
        hint.AddThemeColorOverride("font_shadow_color", Colors.Black);
        hint.AddThemeConstantOverride("shadow_offset_x", 2);
        hint.AddThemeConstantOverride("shadow_offset_y", 2);
        layer.AddChild(hint);
    }

    private void AddTouchButton(CanvasLayer layer, string label, string action, Vector2 offset)
    {
        var button = new Button();
        button.Text = label;
        button.Size = new Vector2(88, 88);
        button.AnchorLeft = 0;
        button.AnchorRight = 0;
        button.AnchorTop = 1;
        button.AnchorBottom = 1;
        button.Position = offset;
        button.AddThemeFontSizeOverride("font_size", 28);
        button.ButtonDown += () => Input.ActionPress(action);
        button.ButtonUp += () => Input.ActionRelease(action);
        layer.AddChild(button);
    }

    private Node3D CreateBox(string nodeName, Vector3 position, Vector3 size, Color color, bool collision)
    {
        Node3D root;

        if (collision)
        {
            var body = new StaticBody3D();
            body.Name = nodeName;
            body.Position = position;

            var boxShape = new BoxShape3D();
            boxShape.Size = size;
            var shapeNode = new CollisionShape3D();
            shapeNode.Shape = boxShape;
            body.AddChild(shapeNode);

            root = body;
        }
        else
        {
            root = new Node3D();
            root.Name = nodeName;
            root.Position = position;
        }

        var mesh = new BoxMesh();
        mesh.Size = size;
        var visual = new MeshInstance3D();
        visual.Mesh = mesh;
        visual.MaterialOverride = Material(color);
        root.AddChild(visual);

        if (collision)
            root.Position = position;

        AddChild(root);
        return root;
    }

    private StandardMaterial3D Material(Color color)
    {
        return new StandardMaterial3D { AlbedoColor = color, Roughness = 1.0f };
    }
}
