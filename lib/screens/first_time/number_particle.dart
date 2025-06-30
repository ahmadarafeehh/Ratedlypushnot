class NumberParticle {
  double x;
  double y;
  double speed;
  double rotation;
  double rotationSpeed;
  double opacity; // Higher values = more visible
  int number;
  double fontSize; // Larger values = bigger numbers
  double sway;
  double swaySpeed;

  NumberParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    required this.opacity,
    required this.number,
    required this.fontSize,
    required this.sway,
    required this.swaySpeed,
  });
}
