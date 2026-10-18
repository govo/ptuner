#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
管理 App Store Connect 订阅本地化。
Fastlane 原生不支持订阅/IAP 元数据，因此直接调用 ASC REST API。
"""

import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path

import requests


def load_private_key(path: str) -> str:
    with open(path, "r") as f:
        return f.read().strip()


def make_jwt(issuer_id: str, key_id: str, key_path: str) -> str:
    try:
        import jwt
    except ImportError:
        print("缺少 PyJWT，请先安装: pip3 install PyJWT cryptography", file=sys.stderr)
        sys.exit(1)

    private_key = load_private_key(key_path)
    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    headers = {"kid": key_id, "typ": "JWT"}
    token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)
    # PyJWT 2.x 返回 str，1.x 返回 bytes
    return token if isinstance(token, str) else token.decode("utf-8")


class AppStoreConnectClient:
    BASE_URL = "https://api.appstoreconnect.apple.com/v1"

    def __init__(self, issuer_id: str, key_id: str, key_path: str):
        self.jwt = make_jwt(issuer_id, key_id, key_path)
        self.session = requests.Session()
        self.session.headers.update({"Authorization": f"Bearer {self.jwt}"})

    def _get(self, path: str, params: dict = None) -> dict:
        url = f"{self.BASE_URL}{path}"
        response = self.session.get(url, params=params)
        response.raise_for_status()
        return response.json()

    def _post(self, path: str, json_data: dict) -> dict:
        url = f"{self.BASE_URL}{path}"
        response = self.session.post(url, json=json_data)
        response.raise_for_status()
        return response.json()

    def _patch(self, path: str, json_data: dict) -> dict:
        url = f"{self.BASE_URL}{path}"
        response = self.session.patch(url, json=json_data)
        response.raise_for_status()
        return response.json()

    def list_subscription_groups(self, app_id: str) -> list:
        data = self._get(f"/apps/{app_id}/subscriptionGroups")
        return data.get("data", [])

    def list_subscriptions(self, group_id: str) -> list:
        data = self._get(f"/subscriptionGroups/{group_id}/subscriptions")
        return data.get("data", [])

    def list_subscription_localizations(self, subscription_id: str) -> list:
        data = self._get(f"/subscriptions/{subscription_id}/subscriptionLocalizations")
        return data.get("data", [])

    def list_subscription_group_localizations(self, group_id: str) -> list:
        data = self._get(f"/subscriptionGroups/{group_id}/subscriptionGroupLocalizations")
        return data.get("data", [])

    def create_subscription_localization(
        self, subscription_id: str, locale: str, name: str, description: str
    ) -> dict:
        body = {
            "data": {
                "type": "subscriptionLocalizations",
                "attributes": {
                    "locale": locale,
                    "name": name,
                    "description": description,
                },
                "relationships": {
                    "subscription": {
                        "data": {
                            "type": "subscriptions",
                            "id": subscription_id,
                        }
                    }
                },
            }
        }
        return self._post("/subscriptionLocalizations", body)

    def update_subscription_localization(
        self, localization_id: str, name: str, description: str
    ) -> dict:
        body = {
            "data": {
                "type": "subscriptionLocalizations",
                "id": localization_id,
                "attributes": {
                    "name": name,
                    "description": description,
                },
            }
        }
        return self._patch(f"/subscriptionLocalizations/{localization_id}", body)


def cmd_list(args) -> int:
    client = AppStoreConnectClient(args.issuer_id, args.key_id, args.key_path)
    groups = client.list_subscription_groups(args.app_id)
    if not groups:
        print(f"未找到订阅组 (app_id={args.app_id})")
        return 0

    for group in groups:
        group_id = group["id"]
        ref_name = group["attributes"].get("referenceName", "")
        print(f"订阅组: {ref_name} ({group_id})")

        group_localizations = client.list_subscription_group_localizations(group_id)
        if group_localizations:
            print("  订阅组本地化:")
            for loc in group_localizations:
                loc_attrs = loc["attributes"]
                print(f"    [{loc_attrs.get('locale', '')}] {loc_attrs.get('name', '')}")

        subscriptions = client.list_subscriptions(group_id)
        for sub in subscriptions:
            sub_id = sub["id"]
            attrs = sub["attributes"]
            print(
                f"  订阅: {attrs.get('name', '')} | productId: {attrs.get('productId', '')} | id: {sub_id}"
            )

            localizations = client.list_subscription_localizations(sub_id)
            for loc in localizations:
                loc_attrs = loc["attributes"]
                print(
                    f"    [{loc_attrs.get('locale', '')}] {loc_attrs.get('name', '')} — {loc_attrs.get('description', '')}"
                )
    return 0


def build_localized_text(locale: str, prefix: str) -> tuple:
    # 占位文案，后续替换为真实本地化文案
    if locale == "de-DE":
        return f"{prefix} Deutsch", "Vollzugriff auf alle Pro-Funktionen"
    if locale == "en-US":
        return prefix, "Full access to all Pro features"
    if locale == "es-ES":
        return f"{prefix} Español", "Acceso completo a todas las funciones Pro"
    if locale == "fr-FR":
        return f"{prefix} Français", "Accès complet à toutes les fonctionnalités Pro"
    if locale == "ja":
        return f"{prefix} 日本語", "すべてのPro機能へフルアクセス"
    if locale == "ko":
        return f"{prefix} 한국어", "모든 Pro 기능에 대한 전체 액세스"
    if locale == "zh-Hans":
        return f"{prefix} 简体中文", "解锁全部 Pro 功能"
    if locale == "zh-Hant":
        return f"{prefix} 繁體中文", "解鎖全部 Pro 功能"
    return prefix, "Full access to all Pro features"


def cmd_update(args) -> int:
    client = AppStoreConnectClient(args.issuer_id, args.key_id, args.key_path)
    subscriptions = []

    groups = client.list_subscription_groups(args.app_id)
    for group in groups:
        subscriptions.extend(client.list_subscriptions(group["id"]))

    weekly = next(
        (s for s in subscriptions if s["attributes"].get("productId") == args.weekly_product_id),
        None,
    )
    yearly = next(
        (s for s in subscriptions if s["attributes"].get("productId") == args.yearly_product_id),
        None,
    )

    if not weekly:
        print(f"未找到周订阅: {args.weekly_product_id}", file=sys.stderr)
        return 1
    if not yearly:
        print(f"未找到年订阅: {args.yearly_product_id}", file=sys.stderr)
        return 1

    target_locales = args.locales.split(",")

    for sub, prefix in [(weekly, args.weekly_name), (yearly, args.yearly_name)]:
        sub_id = sub["id"]
        existing = client.list_subscription_localizations(sub_id)
        existing_by_locale = {
            loc["attributes"]["locale"]: loc for loc in existing if "locale" in loc["attributes"]
        }

        for locale in target_locales:
            name, description = build_localized_text(locale, prefix)
            if locale in existing_by_locale:
                if args.skip_existing:
                    print(f"跳过 [{locale}] {prefix}: 已存在")
                    continue
                loc_id = existing_by_locale[locale]["id"]
                client.update_subscription_localization(loc_id, name, description)
                print(f"更新 [{locale}] {prefix}: {name}")
            else:
                client.create_subscription_localization(sub_id, locale, name, description)
                print(f"创建 [{locale}] {prefix}: {name}")

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="管理 App Store Connect 订阅本地化")
    parser.add_argument("--issuer-id", required=True, help="App Store Connect API Issuer ID")
    parser.add_argument("--key-id", required=True, help="App Store Connect API Key ID")
    parser.add_argument("--key-path", required=True, help="Path to AuthKey_*.p8")
    parser.add_argument("--app-id", required=True, help="Numeric App Store App ID")

    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="列出所有订阅及本地化")
    list_parser.set_defaults(func=cmd_list)

    update_parser = subparsers.add_parser("update", help="更新 Pro 订阅本地化")
    update_parser.add_argument("--weekly-product-id", required=True)
    update_parser.add_argument("--yearly-product-id", required=True)
    update_parser.add_argument("--weekly-name", default="Pro Weekly")
    update_parser.add_argument("--yearly-name", default="Pro Yearly")
    update_parser.add_argument(
        "--locales",
        default="de-DE,en-US,es-ES,fr-FR,ja,ko,zh-Hans,zh-Hant",
        help="逗号分隔的 locale 列表",
    )
    update_parser.add_argument(
        "--skip-existing",
        action="store_true",
        default=False,
        help="跳过已存在的本地化，仅创建缺失的语言",
    )
    update_parser.set_defaults(func=cmd_update)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
