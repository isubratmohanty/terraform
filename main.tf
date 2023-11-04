# Configure the AWS provider
provider "aws" {
  region = "eu-west-1"
  access_key = "YOUR_ACCESS_KEY"   #just testing no user created
  secret_key = "YOUR_SECRET_KEY"   #jfor testing no user 
}

#create a VPC for all operation
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "my-vpc"
  }
}

# Create public and private subnets
resource "aws_subnet" "public_subnet" {
  count = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = element(["10.0.1.0/24", "10.0.2.0/24"], count.index)
  availability_zone       = element(["us-west-2a", "us-west-2b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

resource "aws_subnet" "private_subnet" {
  count = 2
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = element(["10.0.3.0/24", "10.0.4.0/24"], count.index)

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Attach the Internet Gateway to the VPC
resource "aws_vpc_attachment" "my_vpc_attachment" {
  vpc_id             = aws_vpc.my_vpc.id
  internet_gateway_id = aws_internet_gateway.my_igw.id
}


# Create a Security Group for an EC2 instance
resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port     = "${var.server_port}"
    to_port         = "${var.server_port}"
    protocol      = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an EC2 instance
resource "aws_instance" "example" {
  ami                                   = "ami-05c0f5389589545b7"
  instance_type           = "t2.micro"
  vpc_security_group_ids  = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  tags {
    Name = "terraform-example"
  }
}
# Create a Security Group for an ELB
resource "aws_security_group" "elb" {
  name = "terraform-example-elb"

  ingress {
    from_port     = 80
          to_port                 = 80
          protocol        = "tcp"
          cidr_blocks   = ["0.0.0.0/0"]
  }

  egress {
    from_port     = 0
          to_port                 = 0
          protocol        = "-1"          cidr_blocks   = ["0.0.0.0/0"]
  }
}

# Create a Launch Configuration
resource "aws_launch_configuration" "example" {
  image_id                  = "ami-785db401"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Create an Autoscaling Group
resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]

  load_balancers       = ["${aws_elb.example.name}"]
  health_check_type    = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

# Create an ELB
resource "aws_elb" "example" {
  name               = "terraform-asg-example"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups    = ["${aws_security_group.elb.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:${var.server_port}/"
  }
}

# Create a S3 bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket                  = "${var.bucket_name}"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

# create a security group for eks cluster
#create a eks cluster
resource "aws_eks_cluster" "my_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    subnet_ids = ["subnet id 1", "subnet 2"]
    }
}

#create node
resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = ["subnet id 1", "subnet id 2"]
  instance_types  = ["t2.micro"]
}

# create a Iam Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "var.current_version",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# create a iam role for node
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "var.current_version",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}


#creating kubernets infra
provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "website" {
  metadata {
    name = "website-namespace"
  }
}

resource "kubernetes_deployment" "website" {
  metadata {
    name      = "website-deployment"
    namespace = kubernetes_namespace.website.metadata[0].name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "website"
      }
    }

    template {
      metadata {
        labels = {
          app = "website"
        }
      }

      spec {
        container {
          name  = "website-container"
          image = "nginx:latest"  
          # Define environment variables as needed
          env {
            name  = "DATABASE_HOST"
            value = "your-database-host"
          }

         }
      }
    }
  }
}

resource "kubernetes_service" "website" {
  metadata {
    name      = "website-service"
    namespace = kubernetes_namespace.website.metadata[0].name
  }

  spec {
    selector = {
      app = "website"
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}

# create a kubernetes service
resource "kubernetes_ingress" "website" {
  metadata {
    name      = "website-ingress"
    namespace = kubernetes_namespace.website.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    rule {
      host = "www.google.com"
      http {
        path {
          path    = "/"
          backend {
            service_name = kubernetes_service.website.metadata[0].name
            service_port = kubernetes_service.website.spec[0].port[0].port
          }
        }
      }
    }
  }
}
                                                                                                                                                            270,0-1 85%



                                                                                                                                                                  253,0-1 78%


                                                                                                                                                                    148,1 37%


                                                                                                                                                                    56,1 19%


