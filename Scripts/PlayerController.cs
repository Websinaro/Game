using Godot;

public partial class PlayerController : CharacterBody3D
{
    [Export] public float MoveSpeed { get; set; } = 5.0f;
    [Export] public float Gravity { get; set; } = 18.0f;

    public override void _PhysicsProcess(double delta)
    {
        Vector2 input = Input.GetVector(
            "move_left", "move_right", "move_forward", "move_back");

        Vector3 direction = new Vector3(input.X, 0, input.Y).Normalized();

        Velocity = new Vector3(direction.X * MoveSpeed, Velocity.Y, direction.Z * MoveSpeed);

        if (!IsOnFloor())
            Velocity = new Vector3(Velocity.X, Velocity.Y - Gravity * (float)delta, Velocity.Z);
        else if (Velocity.Y < 0)
            Velocity = new Vector3(Velocity.X, 0, Velocity.Z);

        MoveAndSlide();
    }
}
