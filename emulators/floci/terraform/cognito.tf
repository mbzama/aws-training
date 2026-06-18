resource "aws_cognito_user_pool" "main" {
  name = "EventBookingUserPool"

  password_policy {
    minimum_length    = 8
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }

  tags = {
    Environment = local.environment
    Project     = local.project_name
  }
}

resource "aws_cognito_user_pool_client" "main" {
  name             = "EventBookingClient"
  user_pool_id     = aws_cognito_user_pool.main.id
  generate_secret  = false
}

resource "aws_cognito_user" "demo" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = "demo@example.com"
  password     = "Demo@123456"

  attributes = {
    email          = "demo@example.com"
    email_verified = "true"
  }

  message_action = "SUPPRESS"

  depends_on = [aws_cognito_user_pool.main]
}
