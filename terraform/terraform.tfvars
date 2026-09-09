

name = "terraform-project"


cidr = "10.0.0.0/16"

azs = [
  "ap-south-1a",
  "ap-south-1b"
]

public_subnets = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnets = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]

aws_region = "ap-south-1"



eticket_image_tag = "latest"

eticket_container_port = 3000

eticket_cpu = 256

eticket_memory = 512

eticket_desired_count = 1

eticket_health_check_path = "/"



stickynotes_image_tag = "latest"

stickynotes_container_port = 3001

stickynotes_cpu = 256

stickynotes_memory = 512

stickynotes_desired_count = 1

stickynotes_health_check_path = "/"



alert_email = "rajapandi6321613@gmail.com"

alert_phone = "+917604961578"