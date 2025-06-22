resource "aws_guardduty_detector" "main" {
  enable = true
}

resource "aws_guardduty_member" "self" {
  detector_id          = aws_guardduty_detector.main.id
  account_id           = var.account_id
  email                = var.account_email
  invite               = false
}
