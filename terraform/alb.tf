# ══════════════════════════════════════════════════════════════════
# ALB — External (internet-facing) + Internal (private)
# ══════════════════════════════════════════════════════════════════

# ── External ALB ─────────────────────────────────────────────────
resource "aws_lb" "external" {
  name                       = "${var.project}-alb-external"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_external.id]
  subnets                    = aws_subnet.public[*].id
  enable_deletion_protection = false
  tags                       = merge(local.common_tags, { Name = "${var.project}-alb-external" })
}

resource "aws_lb_target_group" "public_ec2" {
  name        = "${var.project}-tg-public"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
  tags = merge(local.common_tags, { Name = "${var.project}-tg-public" })
}

resource "aws_lb_target_group_attachment" "public_ec2" {
  count            = 2
  target_group_arn = aws_lb_target_group.public_ec2.arn
  target_id        = aws_instance.public[count.index].id
  port             = 80
}

resource "aws_lb_listener" "external_http" {
  load_balancer_arn = aws_lb.external.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.public_ec2.arn
  }
}

# ── Internal ALB ─────────────────────────────────────────────────
resource "aws_lb" "internal" {
  name                       = "${var.project}-alb-internal"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_internal.id]
  subnets                    = aws_subnet.private[*].id
  enable_deletion_protection = false
  tags                       = merge(local.common_tags, { Name = "${var.project}-alb-internal" })
}

resource "aws_lb_target_group" "private_ec2" {
  name        = "${var.project}-tg-private"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
  tags = merge(local.common_tags, { Name = "${var.project}-tg-private" })
}

resource "aws_lb_target_group_attachment" "private_ec2" {
  count            = 2
  target_group_arn = aws_lb_target_group.private_ec2.arn
  target_id        = aws_instance.private[count.index].id
  port             = 8080
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private_ec2.arn
  }
}
