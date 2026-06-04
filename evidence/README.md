# Evidence

Luu anh bang chung trong folder nay.

## Test K8s self-healing

Luu y: cac lenh `kubectl` chi chay duoc sau khi SSH vao EC2 vi minikube nam trong EC2.

SSH vao EC2:

```bash
$(terraform output -raw ssh_command)
```

Chay tung lenh va chup anh tuong ung:

```bash
kubectl get pods -l app=welcome-xbrain -o wide
```

Anh: `evidence/k8s-pods-before-delete.png`

```bash
kubectl delete pod -l app=welcome-xbrain
```

Anh: `evidence/k8s-delete-pods-command.png`

```bash
kubectl get pods -l app=welcome-xbrain -w
```

Anh: `evidence/k8s-pods-recreated.png`

Mo terminal local trong folder Terraform va test URL:

```bash
curl -i "$(terraform output -raw app_url)"
```

Lenh tren lay URL public tu output Terraform. URL co the la ALB DNS hoac domain Route53 neu da cau hinh domain.

Anh: `evidence/k8s-url-after-recreate.png`
