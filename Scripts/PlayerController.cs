using Godot;

public partial class PlayerController : CharacterBody3D
{
    [Export] public float MoveSpeed { get; set; } = 5.0f;
    [Export] public float Acceleration { get; set; } = 18.0f;
    [Export] public float JumpVelocity { get; set; } = 4.5f;

    private float _gravity = 9.8f;

    public override void _Ready()
    {
        _gravity = (float)ProjectSettings.GetSetting("physics/3d/default_gravity");

        AddChild(new CollisionShape3D
        {
            Shape = new CapsuleShape3D { Radius = 0.42f, Height = 1.8f },
            Position = new Vector3(0f, 0.9f, 0f)
        });

        AddChild(new MeshInstance3D
        {
            Name = "PlayerVisual",
            Mesh = new CapsuleMesh
            {
                Radius = 0.42f,
                Height = 1.8f,
                Material = new StandardMaterial3D { AlbedoColor = new Color(0.12f, 0.28f, 0.72f) }
            },
            Position = new Vector3(0f, 0.9f, 0f)
        });

        var camera = new Camera3D
        {
            Name = "PlayerCamera",
            Position = new Vector3(0f, 4.2f, 7.5f),
            Current = true,
            Fov = 70f
        };
        AddChild(camera);
        camera.LookAt(new Vector3(0f, 1f, 0f), Vector3.Up);
    }

    public override void _PhysicsProcess(double delta)
    {
        float dt = (float)delta;

        if (!IsOnFloor())
            Velocity = new Vector3(Velocity.X, Velocity.Y - _gravity * dt, Velocity.Z);

        Vector2 input = Input.GetVector("move_left", "move_right", "move_forward", "move_back");
        Vector3 direction = new Vector3(input.X, 0f, input.Y).Normalized();

        Vector3 targetVelocity = direction * MoveSpeed;
        Velocity = new Vector3(
            Mathf.MoveToward(Velocity.X, targetVelocity.X, Acceleration * dt),
            Velocity.Y,
            Mathf.MoveToward(Velocity.Z, targetVelocity.Z, Acceleration * dt)
        );

        if (Input.IsActionJustPressed("jump") && IsOnFloor())
            Velocity = new Vector3(Velocity.X, JumpVelocity, Velocity.Z);

        MoveAndSlide();
    }
}
