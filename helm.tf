


/*
locals {
  electionID = "external-ingress-controller-leader" # multiple pods, one controller election ID = name 
  ingressClassResource = {
    name = "external-nginx" #annotate ingress with this name to specify if it's public or private, defines the class shown in k get ingress
    #problem = election ID of just nginx, but it was the master of both external and internal
    enabled = true
    default = true
    controllerValue : "k8s.io/external-ingress-nginx"
  }
  service = {
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "tcp"
      "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = true
      "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol"                    = "*"
    }
  }



  internal_ingress_values = {
    controller = {
      electionID = "internal-ingress-controller-leader"
      ingressClassResource = {
        name    = "internal-nginx"
        enabled = true
        default = false
        controllerValue : "k8s.io/internal-ingress-nginx"
      }
      service = {
        external = {
          enabled = false
        }
        internal = {
          enabled = true
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "tcp"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = true
            "service.beta.kubernetes.io/aws-load-balancer-internal"                          = true
            "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol"                    = "*"
          }
        }
      }
    }
  }
}


# Cert Manager

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "kube-system"
  depends_on = [module.eks]

  values = [
    yamlencode({
      cainjector = {
        serviceAccount = {
          name = "cert-manager-cainjector"
        }
      }
      global = {
        leaderElection = {
          namespace = "kube-system"
        }
      }
      installCRDs = true
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.cert_manager_irsa_role.iam_role_arn
        }
        name = "cert-manager"
      }
      startupapicheck = {
        serviceAccount = {
          name = "cert-manager-startupapicheck"
        }
      }
      webhook = {
        serviceAccount = {
          name = "cert-manager-webhook"
        }
      }

      }
    )
  ]
}

# External DNS

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "external-dns"
  depends_on       = [module.eks]
  create_namespace = true
  namespace        = "kube-system"



  values = [
    yamlencode({
      provider : "aws",
      aws : {
        region : "us-east-2"
      },
      txtOwnerId : module.eks.cluster_name
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.external_dns_irsa_role.iam_role_arn
        }
        name = "external-dns"
      }
      sources       = ["ingress"]
      domainFilters = ["ljroy.com"]
      crd = {
      create = true }
    })

  ]
}

# ingress-nginx = open source free
# nginx-ingress = nginx plus

resource "helm_release" "external-nginx" {
  name       = "external-nginx"
  chart      = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  version    = "^4.1.1"
  namespace  = "kube-system"
  depends_on = [module.eks]
  values = [yamlencode({
    controller = {
      ingressClassResource = {
        name    = "external-nginx"
        enabled = true
        default = true
        controllerValue : "k8s.io/external-ingress-nginx"
      }
      service = {
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "tcp"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = true
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol"                    = "*"
        }
      }
    }
  })]
}


resource "kubernetes_manifest" "cert-issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"

    metadata = {
      name = "letsencrypt-production"
    }

    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "julien@ljroy.com"
        privateKeySecretRef = {
          name = "letsencrypt-production-key"
        }

        solvers = [
          {
            selector = {
              dnsZones = ["ljroy.com"]
            }
            dns01 = {
              route53 = {
                region       = "us-east-2"
                hostedZoneID = aws_route53_zone.myZone.zone_id #"Z01852593T24R33N47W1U"
              }
            }
          }
        ]


      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

resource "kubernetes_manifest" "someservice" {
  manifest = yamldecode(<<-EOF
  apiVersion: v1
  kind: Service
  metadata:
    name: game-service
    namespace: default
  spec:
    selector:
      app: game
    ports:
      - protocol: TCP
        port: 80
        targetPort: 80
  EOF
  )
}

resource "kubernetes_manifest" "game" {
  manifest = yamldecode(<<-EOF
  apiVersion: apps/v1
  kind: Deployment
  metadata:
      name: game
      namespace: default
  spec:
    replicas: 1
    selector:
      matchLabels:
       app: game
    template:
      metadata:
        labels:
          app: game
      spec:
        containers:
          - name: game
            image: blackicebird/2048:latest
            resources:
              requests:
                memory: "250Mi"
                cpu: "250m"
              limits:
                memory: "500Mi"
                cpu: "500m"  
            ports: 
              - containerPort: 80
            EOF
  )
}

/*
resource "kubernetes_manifest" "testserv" {
  manifest = yamldecode(<<-EOF
  apiVersion: v1
  kind: Service
  metadata:
    name: meme-service
    namespace: default
  spec:
    selector:
      app: meme
    ports:
      - protocol: TCP
        port: 80
        targetPort: 80
  EOF
  )
}

resource "kubernetes_manifest" "tester" {
  manifest = yamldecode(<<-EOF
  apiVersion: apps/v1
  kind: Deployment
  metadata:
      name: test-deploy
      namespace: default
  spec:
    replicas: 1
    selector:
      matchLabels:
       app: meme
    template:
      metadata:
        labels:
          app: meme
      spec:
        containers:
          - name: meme
            image: public.ecr.aws/z0z3i0h3/myrepo:meme
            resources:
              requests:
                memory: "250Mi"
                cpu: "250m"
              limits:
                memory: "500Mi"
                cpu: "500m"  
            ports: 
              - containerPort: 80
            EOF
  )
}

*/
