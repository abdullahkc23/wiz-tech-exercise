resource "aws_ecr_repository" "tasky_repo" {
  name                 = "tasky"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
