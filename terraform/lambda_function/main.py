import os
import boto3
import json
import requests
from datetime import datetime, timedelta, date

# TODO: 環境変数化
TEAMS_WEBHOOK_URL = os.getenv('TEAMS_WEBHOOK_URL')


def lambda_handler(event, context) -> None:
    client = boto3.client("ce", region_name="ap-northeast-1")

    # 合計とサービス毎の請求額を取得する
    total_billing = get_total_billing(client)
    service_billings = get_service_billings(client)

    # teams用のメッセージを作成して投げる
    (title, detail) = get_message(total_billing, service_billings)
    print(f"title: {title}")
    print(f"detail: {detail}")
    post_teams(title, detail, service_billings)


def get_total_billing(client) -> dict:
    (start_date, end_date) = get_total_cost_date_range()

    # https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ce.html#CostExplorer.Client.get_cost_and_usage
    response = client.get_cost_and_usage(
        TimePeriod={"Start": start_date, "End": end_date},
        Granularity="MONTHLY",
        Metrics=["AmortizedCost"],
    )
    return {
        "start": response["ResultsByTime"][0]["TimePeriod"]["Start"],
        "end": response["ResultsByTime"][0]["TimePeriod"]["End"],
        "billing": response["ResultsByTime"][0]["Total"]["AmortizedCost"]["Amount"],
    }


def get_service_billings(client) -> list:
    (start_date, end_date) = get_total_cost_date_range()

    # https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ce.html#CostExplorer.Client.get_cost_and_usage
    response = client.get_cost_and_usage(
        TimePeriod={"Start": start_date, "End": end_date},
        Granularity="MONTHLY",
        Metrics=["AmortizedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )

    billings = []

    for item in response["ResultsByTime"][0]["Groups"]:
        billings.append(
            {
                "service_name": item["Keys"][0],
                "billing": item["Metrics"]["AmortizedCost"]["Amount"],
            }
        )
    return billings


def get_message(total_billing: dict, service_billings: list) -> (str, str):
    start = datetime.strptime(total_billing["start"], "%Y-%m-%d").strftime("%m/%d")

    # Endの日付は結果に含まないため、表示上は前日にしておく
    end_today = datetime.strptime(total_billing["end"], "%Y-%m-%d")
    end_yesterday = (end_today - timedelta(days=1)).strftime("%m/%d")

    total = round(float(total_billing["billing"]), 2)

    title = f"{start}～{end_yesterday}の請求額は、{total:.2f} USDです。"

    details = []
    for item in service_billings:
        service_name = item["service_name"]
        billing = round(float(item["billing"]), 2)

        if billing == 0.0:
            # 請求無し（0.0 USD）の場合は、内訳を表示しない
            continue
        details.append(f"　・{service_name}: {billing:.2f} USD")

    return title, "\n".join(details)


def post_teams(title: str, detail: str, service_billings: list) -> None:
    # https://docs.microsoft.com/ja-jp/microsoftteams/platform/webhooks-and-connectors/how-to/connectors-using?tabs=cURL
    # payload = {
    #     'title': title,
    #     'text': detail
    # }

    facts = []
    for item in service_billings:
        service_name = item["service_name"]
        billing = round(float(item["billing"]), 2)

        if billing == 0.0:
            # 請求無し（0.0 USD）の場合は、内訳を表示しない
            continue
        dict_tmp = {
            "name": f"{billing:.2f} USD",
            "value": service_name,
            "billing": billing,
        }
        facts.append(dict_tmp)

    facts_sorted_by_billing = sorted(facts, key=lambda x: x["billing"], reverse=True)

    # ソート用に保持していたbilling要素を削除
    for item in facts_sorted_by_billing:
        del item["billing"]

    payload = {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "themeColor": "0076D7",
        "summary": title,
        "sections": [
            {
                "activityTitle": title,
                "activitySubtitle": "サービス別利用金額(金額降順)",
                "activityImage": "https://img.icons8.com/color/50/000000/amazon-web-services.png",
                "facts": facts_sorted_by_billing,
                "markdown": "true",
                "potentialAction": [
                    {
                        "@type": "OpenUri",
                        "name": "Cost Management Console",
                        "targets": [
                            {
                                "os": "default",
                                "uri": "https://console.aws.amazon.com/cost-management/home?region=ap-northeast-1#/dashboard",
                            }
                        ],
                    }
                ],
            }
        ],
    }

    try:
        response = requests.post(TEAMS_WEBHOOK_URL, data=json.dumps(payload))
    except requests.exceptions.RequestException as e:
        print(e)
    else:
        print(response.status_code)


def get_total_cost_date_range() -> (str, str):
    start_date = get_begin_of_month()
    end_date = get_today()

    # get_cost_and_usage()のstartとendに同じ日付は指定不可のため、
    # 「今日が1日」なら、「先月1日から今月1日（今日）」までの範囲にする
    if start_date == end_date:
        end_of_month = datetime.strptime(start_date, "%Y-%m-%d") + timedelta(days=-1)
        begin_of_month = end_of_month.replace(day=1)
        return begin_of_month.date().isoformat(), end_date
    return start_date, end_date


def get_begin_of_month() -> str:
    return date.today().replace(day=1).isoformat()


def get_prev_day(prev: int) -> str:
    return (date.today() - timedelta(days=prev)).isoformat()


def get_today() -> str:
    return date.today().isoformat()
