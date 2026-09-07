data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

module "my_server" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name                   = "tf4-rackula"
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = module.my_vpc.public_subnets[0]
  create_security_group  = false
  vpc_security_group_ids = [module.my_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  user_data = templatefile("userdata.sh", {})
  tags      = { Name = "tf4-rackula" }
}
