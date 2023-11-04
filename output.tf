# Output variable: DNS Name of ELB
output "elb_dns_name" {
  value = "${aws_elb.example.dns_name}"
}

#output varible: eks cluster endpoint
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.my_cluster.endpoint
}
