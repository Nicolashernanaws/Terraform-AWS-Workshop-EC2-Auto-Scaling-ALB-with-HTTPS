output "alb_dns" {
  description = "DNS del Application Load Balancer"
  value       = aws_lb.alb-nc.dns_name
}
