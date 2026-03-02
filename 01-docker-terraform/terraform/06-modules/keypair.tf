resource "aws_key_pair" "ln_ec2_kp" {
  key_name   = "ln_ec2_kp"
  public_key = file(".ssh/ec2_kp.pub")
}
