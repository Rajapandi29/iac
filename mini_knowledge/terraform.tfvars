aws_region = "us-east-1"

app_name = "rag-app"

environment = "production"



vpc_cidr = "10.50.0.0/16"

azs = [
  "us-east-1a",
  "us-east-1b"
]

public_subnets = [
  "10.50.1.0/24",
  "10.50.2.0/24"
]

private_subnets = [
  "10.50.11.0/24",
  "10.50.12.0/24"
]

=

streamlit_port = 8501

fastapi_port = 8000



streamlit_image_tag = "v1"

fastapi_image_tag = "v1"



neon_api_key = "napi_0qvdpwqyefes6x3zzfmqyr7h16rgvd1q3g7gxg69i7lqlkx1u28yh0t7um6m0ov4"

neon_database_url = "postgresql://USER:PASSWORD@YOUR-NEON-HOST/neondb?sslmode=require"

neon_database_name = "neondb"

neon_database_user = "jagan"

neon_database_password = "123456789"



alert_email = "jagansunil100@gmail.com"