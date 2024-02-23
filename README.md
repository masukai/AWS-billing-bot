# AWS-billing-bot

## 概要

teams に AWS の料金を毎日監視するための bot を作成しました。

## 実行前の確認

- AWS CLI がインストールされている。`~/.aws/credentials`が作成されており、bot を設定したい AWS アカウントが登録されている。作成されているフォルダは大抵以下。

```
/Users/~/.aws/credentials
```

config は以下のように記述（あくまで一例）。

```
[default]
region = ap-northeast-1

[fogefoge1]
region = ap-northeast-1

[fogefoge2]
region = ap-northeast-1

```

credentials は以下のように記述（あくまで一例）。

```
[default]
aws_access_key_id = AKIA~~
aws_secret_access_key = ~~

[fogefoge1]
aws_access_key_id = AKIA~~
aws_secret_access_key = ~~

[fogefoge2]
aws_access_key_id = AKIA~~
aws_secret_access_key = ~~

```

- terraform で[編集すべき箇所](terraform/variables.tf)は以下。

`teams_webhook_url`に`~/.aws/credentialsで設定している今回構築したい環境名`を追加し、
Incoming Webhook から取得できる URL をイコールで結ぶ。

通知時間の設定を行う。
`cron = "cron(0 0 ? * SUN-SAT *)"`
0 0 となっているところが「分」「時」(UTC)に対応、9 時間のズレに留意。

## 実行手順

terraform で AWS を構築していく。`terraform`フォルダの配下まで移動して、以下のコマンドを打っていく。

```
terraform init
terraform workspace new ~/.aws/credentialsで設定している今回構築したい環境名
terraform workspace select ~/.aws/credentialsで設定している今回構築したい環境名
terraform plan
terraform apply
```

> [!Warning]
> bot を AWS から消す・仕舞う・片付けることがしたい場合は`terraform workspace select`コマンドで対応する AWS アカウントに移動し、以下のコマンドを利用。
> `terraform destroy`

> [!Note]
> terraform workspace の便利コマンド
> `terraform workspace list`

## ドキュメント

- [環境構築や詳細について](docs/prepare.md)
