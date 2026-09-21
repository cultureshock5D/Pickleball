# C&J Pickleball Arena — POS Item Master Catalog & Migration Guide

> **Facility**: C&J's Events Place & Sports Arena  
> **Address**: 25 Bologna Muzon, Taytay, Rizal, 1920  
> **Tax System**: Philippine BIR EOPT / 12% VAT Inclusive (with RA 9994 / RA 10754 Senior & PWD Statutory Exemptions)  
> **Target Systems**: Flutter POS Mobile/Tablet App, Desktop POS, ERP, Third-Party Billing Engine  
> **Export Date**: 2026-09-21  
> **Total Categories**: 11  
> **Total POS Products**: 87  
> **Currency**: Philippine Peso (PHP / ₱)

---

## Executive Summary

This document provides the complete, authoritative catalog of all Point of Sale (POS) items, categories, selling prices, cost prices, profit margins, inventory stock levels, and SKUs currently operating in **C&J Pickleball Arena** (Pro Shop, Café Bar & Kitchen).

Use this document to:
1. Review item-by-item details (SKU, Name, Category, Department, Price, Cost, Stock, Reorder Threshold).
2. Seed or migrate data directly into another app (e.g. Flutter POS tablet app, offline local database, or cloud inventory).
3. Validate statutory pricing calculations and stock threshold triggers.

---

## Table of Contents

1. [Department Architecture & Financial Overview](#1-department-architecture--financial-overview)
2. [POS Categories Directory](#2-pos-categories-directory)
3. [Detailed Product Catalog by Category](#3-detailed-product-catalog-by-category)
   - [3.1 Coffee](#31-coffee)
   - [3.2 Decaf Coffee](#32-decaf-coffee)
   - [3.3 Non-Coffee & Tea](#33-non-coffee-tea)
   - [3.4 Fruit Shakes](#34-fruit-shakes)
   - [3.5 Beverages & Hydration](#35-beverages-hydration)
   - [3.6 Silog Meals](#36-silog-meals)
   - [3.7 Snacks & Dimsum](#37-snacks-dimsum)
   - [3.8 Noodles & Pasta](#38-noodles-pasta)
   - [3.9 Rice & Add-ons](#39-rice-add-ons)
   - [3.10 Bar Supplies](#310-bar-supplies)
   - [3.11 Kitchen Supplies](#311-kitchen-supplies)
4. [Master Consolidated Product Table (All 87 Items)](#4-master-consolidated-product-table-all-87-items)
5. [Ready-to-Use Migration Payloads](#5-ready-to-use-migration-payloads)
   - [5.1 JSON Migration Payload](#51-json-migration-payload)
   - [5.2 PostgreSQL / Supabase SQL Migration Script](#52-postgresql--supabase-sql-migration-script)
   - [5.3 Dart / Flutter Seed Model & Embedded Static Catalog](#53-dart--flutter-seed-model--embedded-static-catalog)
   - [5.4 CSV Tabular Export](#54-csv-tabular-export)

---

## 1. Department Architecture & Financial Overview

The catalog is split into **4 main counter departments** and **11 distinct operational categories**:

| Department | Subcategories Included | Item Count | Selling Price Range (₱) | Avg. Margin % | Notes |
|---|---|:---:|:---:|:---:|---|
| **Coffee** | Coffee, Decaf Coffee | 22 | ₱110.00 – ₱165.00 | 50% | Specialty espresso, hot & iced lattes, decaf variants |
| **Drinks** | Non-Coffee & Tea, Fruit Shakes, Beverages & Hydration | 18 | ₱30.00 – ₱130.00 | 50% | Teas, fresh fruit smoothies, sports hydration & sodas |
| **Food** | Silog Meals, Snacks & Dimsum, Noodles & Pasta, Rice & Add-ons | 30 | ₱20.00 – ₱240.00 | 50% | All-day breakfast silogs, fried snacks, dimsum & pasta |
| **Supplies** | Bar Supplies, Kitchen Supplies | 17 | ₱0.00 – ₱0.00 | Internal | Back-of-house consumables, syrups & seasonings (₱0 retail) |
| **TOTAL** | **11 Categories** | **87 Items** | **₱0.00 – ₱240.00** | **~50%** | Complete Facility Inventory |

> **Operational Note on Supplies**: Bar Supplies (`BW-*`) and Kitchen Supplies (`KW-*`) are internal raw material items tracked for inventory count and reorder purposes. Their retail selling price is set to `₱0.00` so they cannot be tendered alone on the cashier register.

---

## 2. POS Categories Directory

| Display Order | Category Name | Slug | Department | Description | Active Status | Category UUID |
|:---:|---|---|---|---|:---:|---|
| 1 | **Coffee** | `coffee` | Coffee | Handcrafted espresso and caffeinated specialty drinks | ✅ Active | `ad2db960-6fcb-4972-807c-7a82a0eaef62` |
| 2 | **Decaf Coffee** | `decaf-coffee` | Coffee | Decaffeinated espresso and specialty lattes | ✅ Active | `665f3975-2c1c-4fc3-999f-f0facb9a44dd` |
| 3 | **Non-Coffee & Tea** | `non-coffee-tea` | Drinks | Hot & iced chocolate, teas, and refreshers | ✅ Active | `aebabe08-d448-4b94-8f1b-b4e821ebb85f` |
| 4 | **Fruit Shakes** | `fruit-shakes` | Drinks | Fresh fruit blended shakes | ✅ Active | `8f978f99-acb0-4fc2-92e3-971d314c971e` |
| 5 | **Beverages & Hydration** | `beverages-hydration` | Drinks | Bottled water, sodas, Pocari Sweat, and Gatorade | ✅ Active | `915e6f8f-a533-4bbd-9cc6-1b10f65fa80a` |
| 6 | **Silog Meals** | `silog-meals` | Food | All-day breakfast meals served with garlic rice & egg | ✅ Active | `88a61c9a-7a45-443f-97b5-0492e680fbde` |
| 7 | **Snacks & Dimsum** | `snacks-dimsum` | Food | Nachos, fries, toge, siomai varieties, and siopao | ✅ Active | `c29fd4d3-ee90-4271-ad3d-8f8a41ded74b` |
| 8 | **Noodles & Pasta** | `noodles-pasta` | Food | Pancit Canton varieties, spaghetti, and pizza | ✅ Active | `a65c4cd0-4828-4ac4-b6fd-10af2a576bc1` |
| 9 | **Rice & Add-ons** | `rice-addons` | Food | Extra rice and sunny side up egg | ✅ Active | `723f38c2-5cc2-4df5-97f9-18fefa0d2705` |
| 10 | **Bar Supplies** | `bar-supplies` | Supplies | Bar syrups, dairy, and weekly bar consumables | ✅ Active | `96a94c7c-0207-4f72-991a-f11677b111cb` |
| 11 | **Kitchen Supplies** | `kitchen-supplies` | Supplies | Kitchen seasoning powders, produce, and dairy | ✅ Active | `3fb61468-d49b-4638-bf99-fcec95841e47` |

---

## 3. Detailed Product Catalog by Category

### 3.1 Coffee

- **Department**: Coffee
- **Slug**: `coffee`
- **Item Count**: 11 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `00-01` | **Long Black** | ₱110.00 | ₱55.00 | 50% | 44 | 10 | ✅ Active | `6979df8e-3d00-4aa1-9e0e-e5536a1ce6c4` |
| `00-02` | **Capuccino** | ₱130.00 | ₱65.00 | 50% | 49 | 10 | ✅ Active | `28d0f9f0-0d86-46a1-83ba-978bdedac326` |
| `00-03` | **Flat White** | ₱135.00 | ₱67.50 | 50% | 47 | 10 | ✅ Active | `0e86ff8d-70f3-4a9c-ba57-0c5ae41915de` |
| `00-04` | **Spanish Latte** | ₱145.00 | ₱72.50 | 50% | 50 | 10 | ✅ Active | `e972ad24-5be1-4fab-9136-626e6c2b3591` |
| `00-05` | **Seasalt Latte** | ₱150.00 | ₱75.00 | 50% | 50 | 10 | ✅ Active | `b67b6d5d-11cc-470b-9526-dc177a8a4c10` |
| `00-06` | **French Vanilla** | ₱145.00 | ₱72.50 | 50% | 50 | 10 | ✅ Active | `1c73ec74-2cad-4950-a543-d097f9651595` |
| `00-07` | **Caramel Macchiato** | ₱150.00 | ₱75.00 | 50% | 50 | 10 | ✅ Active | `8a076bfa-e61d-4e8e-a1d0-0b63d5750d1a` |
| `00-08` | **Salted Caramel** | ₱145.00 | ₱72.50 | 50% | 50 | 10 | ✅ Active | `44a0d096-e68b-431a-a2b5-b7c764fa0d17` |
| `00-09` | **Brown Sugar Latte** | ₱145.00 | ₱72.50 | 50% | 50 | 10 | ✅ Active | `9dc8f952-31a4-47e3-8e7a-c99b1f2bd03e` |
| `00-10` | **Mocha Latte** | ₱150.00 | ₱75.00 | 50% | 50 | 10 | ✅ Active | `8f9e1a52-59f6-4a00-8d59-ae80825eea57` |
| `00-11` | **Choco Hazelnut** | ₱150.00 | ₱75.00 | 50% | 50 | 10 | ✅ Active | `808b0512-e6da-4bc2-9946-40bf6fc271bf` |

### 3.2 Decaf Coffee

- **Department**: Coffee
- **Slug**: `decaf-coffee`
- **Item Count**: 11 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `00-12` | **Americano Decaf** | ₱120.00 | ₱60.00 | 50% | 40 | 10 | ✅ Active | `65b02d09-0d06-4787-9b71-1aa6093ec9e0` |
| `00-13` | **Flat White Decaf** | ₱145.00 | ₱72.50 | 50% | 40 | 10 | ✅ Active | `bd391f2f-4914-4a2a-83d7-3f4638e08294` |
| `00-14` | **Capuccino Decaf** | ₱140.00 | ₱70.00 | 50% | 40 | 10 | ✅ Active | `a2b05a74-58b0-4b34-af46-3ca2f8605cc8` |
| `00-15` | **Spanish Latte Decaf** | ₱155.00 | ₱77.50 | 50% | 40 | 10 | ✅ Active | `ce3982e0-cf51-4c17-b2ab-3e4a776b7750` |
| `00-16` | **French Vanilla Decaf** | ₱155.00 | ₱77.50 | 50% | 40 | 10 | ✅ Active | `22d879a6-8c1c-4836-a890-082a760cc4a4` |
| `00-17` | **Caramel Macchiato Decaf** | ₱160.00 | ₱80.00 | 50% | 40 | 10 | ✅ Active | `03a0f2b8-018e-4e22-b18d-b70d5db37bc4` |
| `00-18` | **Salted Caramel Decaf** | ₱155.00 | ₱77.50 | 50% | 40 | 10 | ✅ Active | `df13732c-2a5c-4dc6-a617-66088a3496a5` |
| `00-19` | **Brown Sugar Latte Decaf** | ₱155.00 | ₱77.50 | 50% | 40 | 10 | ✅ Active | `ff3dc6b9-eab8-4d84-b5de-2d75ca4f24ff` |
| `00-20` | **Seasalt Butterscotch Decaf** | ₱165.00 | ₱82.50 | 50% | 40 | 10 | ✅ Active | `0543de7a-83b8-4057-926f-8a7fa5ec3513` |
| `00-21` | **Mocha Latte Decaf** | ₱160.00 | ₱80.00 | 50% | 40 | 10 | ✅ Active | `a27b17a3-01cf-4183-bb20-579c1bf1c157` |
| `00-22` | **Choco Hazelnut Decaf** | ₱160.00 | ₱80.00 | 50% | 40 | 10 | ✅ Active | `392f0829-f6c3-4fe7-80a1-d6e606f62679` |

### 3.3 Non-Coffee & Tea

- **Department**: Drinks
- **Slug**: `non-coffee-tea`
- **Item Count**: 6 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `00-23` | **Milk Choco** | ₱120.00 | ₱60.00 | 50% | 40 | 10 | ✅ Active | `2a4683d1-473b-4a45-baf1-54b07e6a13dd` |
| `00-24` | **Hot Choco** | ₱120.00 | ₱60.00 | 50% | 40 | 10 | ✅ Active | `86c430f9-a3ef-43df-90a5-e8f0a2f1276c` |
| `00-25` | **Iced Tea** | ₱65.00 | ₱32.50 | 50% | 80 | 10 | ✅ Active | `a45fd9ee-b217-4233-a26b-4893a08cfdd7` |
| `00-26` | **Lychee Aloe** | ₱110.00 | ₱55.00 | 50% | 40 | 10 | ✅ Active | `89dd9ac6-a789-4bbd-ba15-875d73061bf4` |
| `00-27` | **Lychee Lemon** | ₱110.00 | ₱55.00 | 50% | 40 | 10 | ✅ Active | `8fabaf9f-d7f7-407e-bc6e-4ee9310845ba` |
| `00-28` | **Strawberry Sparkle** | ₱115.00 | ₱57.50 | 50% | 40 | 10 | ✅ Active | `d7dbf41c-0073-436a-bfa0-e6dd6be43efb` |

### 3.4 Fruit Shakes

- **Department**: Drinks
- **Slug**: `fruit-shakes`
- **Item Count**: 3 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `00-29` | **Banana Shake** | ₱120.00 | ₱60.00 | 50% | 30 | 10 | ✅ Active | `4479c7a1-8e7f-4cbd-ba67-8239765ff000` |
| `00-30` | **Mango Shake** | ₱130.00 | ₱65.00 | 50% | 30 | 10 | ✅ Active | `88890ce1-36c8-4e59-8ce3-7fba3861694b` |
| `00-31` | **Strawberry Shake** | ₱130.00 | ₱65.00 | 50% | 30 | 10 | ✅ Active | `d8fd6cd9-852f-4387-ba42-12976c69f06d` |

### 3.5 Beverages & Hydration

- **Department**: Drinks
- **Slug**: `beverages-hydration`
- **Item Count**: 9 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `00-32` | **Water** | ₱30.00 | ₱15.00 | 50% | 150 | 10 | ✅ Active | `af197263-1185-42ee-84ac-fd5e40c270b3` |
| `00-33` | **Coke** | ₱55.00 | ₱27.50 | 50% | 59 | 10 | ✅ Active | `d2f08090-f2bd-4380-b13f-0a2dfc9e6ba2` |
| `00-34` | **Royal** | ₱55.00 | ₱27.50 | 50% | 60 | 10 | ✅ Active | `8f7d0acc-25d0-4c36-a19f-7c15e08a58fc` |
| `00-35` | **Sprite** | ₱55.00 | ₱27.50 | 50% | 60 | 10 | ✅ Active | `d05c8e98-326e-451f-9429-6aea06a09571` |
| `00-36` | **Coke Zero** | ₱55.00 | ₱27.50 | 50% | 60 | 10 | ✅ Active | `da9e547d-f016-4f34-8ca2-45b69a4beb24` |
| `00-37` | **Gatorade Blue** | ₱75.00 | ₱37.50 | 50% | 50 | 10 | ✅ Active | `189283f8-b5ad-4daf-8ddd-134aa23b838e` |
| `00-38` | **Gatorade Violet** | ₱75.00 | ₱37.50 | 50% | 50 | 10 | ✅ Active | `a24d6ab3-e81d-4a29-b065-c271f82170c5` |
| `00-39` | **Gatorade Red** | ₱75.00 | ₱37.50 | 50% | 50 | 10 | ✅ Active | `04a2064b-2b5f-4537-bb91-3710b9777dee` |
| `00-40` | **Pocari** | ₱70.00 | ₱35.00 | 50% | 60 | 10 | ✅ Active | `210c3c2e-ac71-4cee-a7b9-cec965a95446` |

### 3.6 Silog Meals

- **Department**: Food
- **Slug**: `silog-meals`
- **Item Count**: 11 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `K00-01` | **Baconsilog** | ₱140.00 | ₱70.00 | 50% | 30 | 10 | ✅ Active | `fd16fb52-910d-4a37-b9a0-92f956d596aa` |
| `K00-02` | **Bangsilog** | ₱155.00 | ₱77.50 | 50% | 30 | 10 | ✅ Active | `4903241b-358d-4f72-9f3a-7e57dce14cef` |
| `K00-03` | **Chickensilog** | ₱150.00 | ₱75.00 | 50% | 30 | 10 | ✅ Active | `acde9161-2a05-4c3a-b0c7-67797339d13a` |
| `K00-04` | **Cornsilog** | ₱130.00 | ₱65.00 | 50% | 30 | 10 | ✅ Active | `82ad034b-919a-4934-891e-1301b7221787` |
| `K00-05` | **Hotsilog** | ₱120.00 | ₱60.00 | 50% | 30 | 10 | ✅ Active | `973f9ab4-bc52-4476-9d0d-5b658746d734` |
| `K00-06` | **Liemposilog** | ₱165.00 | ₱82.50 | 50% | 30 | 10 | ✅ Active | `28b0281e-313c-469a-a059-dac398ff018d` |
| `K00-07` | **Garlic Longsilog** | ₱140.00 | ₱70.00 | 50% | 29 | 10 | ✅ Active | `a4fbb946-e566-4150-9f8f-5acf2768e215` |
| `K00-08` | **Sweet Longsilog** | ₱140.00 | ₱70.00 | 50% | 30 | 10 | ✅ Active | `7ebd1d03-0b1e-4e84-9d1c-9664ddb1841e` |
| `K00-09` | **Tapsilog** | ₱160.00 | ₱80.00 | 50% | 31 | 10 | ✅ Active | `4c0d21f7-6b3c-4a7a-9c2d-6c3df5cfc1fc` |
| `K00-10` | **Tocilog** | ₱145.00 | ₱72.50 | 50% | 27 | 10 | ✅ Active | `8b929727-6483-41cb-9f6d-63b2e88b90dc` |
| `K00-11` | **Spamsilog** | ₱145.00 | ₱72.50 | 50% | 30 | 10 | ✅ Active | `6da38a3d-9baa-4453-9121-d0a6132915a8` |

### 3.7 Snacks & Dimsum

- **Department**: Food
- **Slug**: `snacks-dimsum`
- **Item Count**: 8 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `K00-12` | **Beef Nachos** | ₱150.00 | ₱75.00 | 50% | 23 | 10 | ✅ Active | `53a0e2d1-7368-46d1-bb26-7f758d7554fd` |
| `K00-13` | **Toge** | ₱65.00 | ₱32.50 | 50% | 27 | 10 | ✅ Active | `6d69cd0c-7ff8-4efc-b3ee-bb1ae80642e1` |
| `K00-14` | **Fries** | ₱90.00 | ₱45.00 | 50% | 38 | 10 | ✅ Active | `b7a11614-a94f-4e97-8a70-60bafcdadeaf` |
| `K00-23` | **Siomai Pork** | ₱70.00 | ₱35.00 | 50% | 39 | 10 | ✅ Active | `24a2e369-ce0b-4a8c-ada9-ae17a7ad3f9c` |
| `K00-24` | **Siomai Chicken** | ₱70.00 | ₱35.00 | 50% | 39 | 10 | ✅ Active | `09ce6001-acd0-4209-82c2-6c7da2e7f65d` |
| `K00-25` | **Siomai Beef** | ₱75.00 | ₱37.50 | 50% | 38 | 10 | ✅ Active | `c144a422-b7b0-4be7-b296-ff65623dfa5c` |
| `K00-26` | **Siomai Japanese** | ₱85.00 | ₱42.50 | 50% | 37 | 10 | ✅ Active | `5a023b9a-6c7d-4a2f-afc2-d8660eaa252b` |
| `K00-27` | **Siopao** | ₱70.00 | ₱35.00 | 50% | 24 | 10 | ✅ Active | `d269168c-00ca-40d1-ba5d-f2ffb82e5008` |

### 3.8 Noodles & Pasta

- **Department**: Food
- **Slug**: `noodles-pasta`
- **Item Count**: 8 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `K00-15` | **Pancit Canton Sweet & Spicy** | ₱50.00 | ₱25.00 | 50% | 50 | 10 | ✅ Active | `07a5d27d-4695-4c06-81c2-c958eb62e097` |
| `K00-16` | **Pancit Canton Chilimansi** | ₱50.00 | ₱25.00 | 50% | 50 | 10 | ✅ Active | `f6dacb8d-8bf0-4870-9165-eaf0643d7195` |
| `K00-17` | **Pancit Canton Calamansi** | ₱50.00 | ₱25.00 | 50% | 50 | 10 | ✅ Active | `095ea22a-a66b-4927-8609-5d7065b79018` |
| `K00-18` | **Pancit Canton Hot & Spicy** | ₱50.00 | ₱25.00 | 50% | 50 | 10 | ✅ Active | `ca72cba1-b801-4a25-8254-c8eb63353c0a` |
| `K00-19` | **Pancit Canton Original** | ₱50.00 | ₱25.00 | 50% | 50 | 10 | ✅ Active | `6a1c184d-f98c-4169-9b90-06b0c6ad67b9` |
| `K00-28` | **Spaghetti Longganisa** | ₱140.00 | ₱70.00 | 50% | 25 | 10 | ✅ Active | `f6e7f897-a840-4d1a-82f1-705b9070fdef` |
| `K00-29` | **Spaghetti Meatballs** | ₱150.00 | ₱75.00 | 50% | 25 | 10 | ✅ Active | `f64226f3-e931-40a3-a91b-e7f19668341e` |
| `K00-30` | **Pizza** | ₱240.00 | ₱120.00 | 50% | 20 | 10 | ✅ Active | `890a1a5d-8694-401d-b1f0-65abb3ef4b3b` |

### 3.9 Rice & Add-ons

- **Department**: Food
- **Slug**: `rice-addons`
- **Item Count**: 3 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `K00-20` | **Egg** | ₱20.00 | ₱10.00 | 50% | 100 | 10 | ✅ Active | `4831bd07-70ff-472c-84a4-c95b7a3c5e6d` |
| `K00-21` | **White Rice** | ₱25.00 | ₱12.50 | 50% | 98 | 10 | ✅ Active | `1879a9a2-8fa7-441c-85e8-b2f2853a35d7` |
| `K00-22` | **Garlic Rice** | ₱30.00 | ₱15.00 | 50% | 100 | 10 | ✅ Active | `350c95d2-6b65-4748-a2da-c44312c6281c` |

### 3.10 Bar Supplies

- **Department**: Supplies
- **Slug**: `bar-supplies`
- **Item Count**: 10 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `BW-41` | **Vivo** | ₱0.00 | ₱0.00 | 0% | 10 | 10 | ✅ Active | `60df43f9-b8c2-4658-8332-47e3d5866e9e` |
| `BW-42` | **Fresh Milk** | ₱0.00 | ₱0.00 | 0% | 21 | 10 | ✅ Active | `c33fd977-57f9-4636-9f3a-dd49f60a1f73` |
| `BW-43` | **Oatside** | ₱0.00 | ₱0.00 | 0% | 15 | 10 | ✅ Active | `ee8fbad4-8e40-4fed-83e8-6dda08bfa04f` |
| `BW-44` | **Vanilla Syrup** | ₱0.00 | ₱0.00 | 0% | 5 | 10 | ✅ Active | `ba78a6fc-8ceb-42ff-b429-e2fcc307c267` |
| `BW-45` | **Hazelnut Syrup** | ₱0.00 | ₱0.00 | 0% | 6 | 10 | ✅ Active | `d180810b-62c1-4809-9f1c-61ef2f009c06` |
| `BW-46` | **French Vanilla Syrup** | ₱0.00 | ₱0.00 | 0% | 6 | 10 | ✅ Active | `c13cd4d9-477e-4098-b642-1d690887d51d` |
| `BW-47` | **Caramel Syrup** | ₱0.00 | ₱0.00 | 0% | 6 | 10 | ✅ Active | `68252bdc-6339-46e0-b996-b6bbf8a8205a` |
| `BW-48` | **Chocolate Syrup** | ₱0.00 | ₱0.00 | 0% | 5 | 10 | ✅ Active | `c46acdc6-cf99-422e-af63-8f1af3673e08` |
| `BW-49` | **Lychee** | ₱0.00 | ₱0.00 | 0% | 10 | 10 | ✅ Active | `48022483-3229-4df2-bde3-fd0331892b85` |
| `BW-50` | **Condensed** | ₱0.00 | ₱0.00 | 0% | 24 | 10 | ✅ Active | `30e3cc60-64b6-4a3a-b5e9-ae4513980def` |

### 3.11 Kitchen Supplies

- **Department**: Supplies
- **Slug**: `kitchen-supplies`
- **Item Count**: 7 products

| SKU | Product Name | Selling Price (₱) | Cost Price (₱) | Gross Margin | Stock Level | Reorder At | Status | Product UUID |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `KW-30` | **Cheese Powder** | ₱0.00 | ₱0.00 | 0% | 10 | 10 | ✅ Active | `c699465d-dab2-4c80-b7b4-f02925a283d4` |
| `KW-31` | **BBQ Powder** | ₱0.00 | ₱0.00 | 0% | 10 | 10 | ✅ Active | `dc4becb0-ffc4-4e21-a64c-6515a8f3f3b4` |
| `KW-32` | **Sour Cream Powder** | ₱0.00 | ₱0.00 | 0% | 10 | 10 | ✅ Active | `09103955-d9ce-421c-a932-bf5d224e0def` |
| `KW-33` | **Cucumber** | ₱0.00 | ₱0.00 | 0% | 15 | 10 | ✅ Active | `70001575-ac70-4c43-ab00-46ecc2535471` |
| `KW-34` | **Tomato** | ₱0.00 | ₱0.00 | 0% | 15 | 10 | ✅ Active | `76ba413e-b87d-4d72-acd4-4c060e04c064` |
| `KW-35` | **Eden Cheese** | ₱0.00 | ₱0.00 | 0% | 12 | 10 | ✅ Active | `54ef0dc3-f602-4888-922c-095923584c65` |
| `KW-36` | **Evap** | ₱0.00 | ₱0.00 | 0% | 20 | 10 | ✅ Active | `5f62e485-727c-4fa0-bd35-b6716b0c7ee5` |

---

## 4. Master Consolidated Product Table (All 87 Items)

Sorted sequentially by SKU:

| SKU | Product Name | Category | Dept | Price (₱) | Cost (₱) | Margin | Stock | Reorder | Status | Product UUID |
|---|---|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `00-01` | **Long Black** | Coffee | Coffee | ₱110.00 | ₱55.00 | 50% | 44 | 10 | Active | `6979df8e-3d00-4aa1-9e0e-e5536a1ce6c4` |
| `00-02` | **Capuccino** | Coffee | Coffee | ₱130.00 | ₱65.00 | 50% | 49 | 10 | Active | `28d0f9f0-0d86-46a1-83ba-978bdedac326` |
| `00-03` | **Flat White** | Coffee | Coffee | ₱135.00 | ₱67.50 | 50% | 47 | 10 | Active | `0e86ff8d-70f3-4a9c-ba57-0c5ae41915de` |
| `00-04` | **Spanish Latte** | Coffee | Coffee | ₱145.00 | ₱72.50 | 50% | 50 | 10 | Active | `e972ad24-5be1-4fab-9136-626e6c2b3591` |
| `00-05` | **Seasalt Latte** | Coffee | Coffee | ₱150.00 | ₱75.00 | 50% | 50 | 10 | Active | `b67b6d5d-11cc-470b-9526-dc177a8a4c10` |
| `00-06` | **French Vanilla** | Coffee | Coffee | ₱145.00 | ₱72.50 | 50% | 50 | 10 | Active | `1c73ec74-2cad-4950-a543-d097f9651595` |
| `00-07` | **Caramel Macchiato** | Coffee | Coffee | ₱150.00 | ₱75.00 | 50% | 50 | 10 | Active | `8a076bfa-e61d-4e8e-a1d0-0b63d5750d1a` |
| `00-08` | **Salted Caramel** | Coffee | Coffee | ₱145.00 | ₱72.50 | 50% | 50 | 10 | Active | `44a0d096-e68b-431a-a2b5-b7c764fa0d17` |
| `00-09` | **Brown Sugar Latte** | Coffee | Coffee | ₱145.00 | ₱72.50 | 50% | 50 | 10 | Active | `9dc8f952-31a4-47e3-8e7a-c99b1f2bd03e` |
| `00-10` | **Mocha Latte** | Coffee | Coffee | ₱150.00 | ₱75.00 | 50% | 50 | 10 | Active | `8f9e1a52-59f6-4a00-8d59-ae80825eea57` |
| `00-11` | **Choco Hazelnut** | Coffee | Coffee | ₱150.00 | ₱75.00 | 50% | 50 | 10 | Active | `808b0512-e6da-4bc2-9946-40bf6fc271bf` |
| `00-12` | **Americano Decaf** | Decaf Coffee | Coffee | ₱120.00 | ₱60.00 | 50% | 40 | 10 | Active | `65b02d09-0d06-4787-9b71-1aa6093ec9e0` |
| `00-13` | **Flat White Decaf** | Decaf Coffee | Coffee | ₱145.00 | ₱72.50 | 50% | 40 | 10 | Active | `bd391f2f-4914-4a2a-83d7-3f4638e08294` |
| `00-14` | **Capuccino Decaf** | Decaf Coffee | Coffee | ₱140.00 | ₱70.00 | 50% | 40 | 10 | Active | `a2b05a74-58b0-4b34-af46-3ca2f8605cc8` |
| `00-15` | **Spanish Latte Decaf** | Decaf Coffee | Coffee | ₱155.00 | ₱77.50 | 50% | 40 | 10 | Active | `ce3982e0-cf51-4c17-b2ab-3e4a776b7750` |
| `00-16` | **French Vanilla Decaf** | Decaf Coffee | Coffee | ₱155.00 | ₱77.50 | 50% | 40 | 10 | Active | `22d879a6-8c1c-4836-a890-082a760cc4a4` |
| `00-17` | **Caramel Macchiato Decaf** | Decaf Coffee | Coffee | ₱160.00 | ₱80.00 | 50% | 40 | 10 | Active | `03a0f2b8-018e-4e22-b18d-b70d5db37bc4` |
| `00-18` | **Salted Caramel Decaf** | Decaf Coffee | Coffee | ₱155.00 | ₱77.50 | 50% | 40 | 10 | Active | `df13732c-2a5c-4dc6-a617-66088a3496a5` |
| `00-19` | **Brown Sugar Latte Decaf** | Decaf Coffee | Coffee | ₱155.00 | ₱77.50 | 50% | 40 | 10 | Active | `ff3dc6b9-eab8-4d84-b5de-2d75ca4f24ff` |
| `00-20` | **Seasalt Butterscotch Decaf** | Decaf Coffee | Coffee | ₱165.00 | ₱82.50 | 50% | 40 | 10 | Active | `0543de7a-83b8-4057-926f-8a7fa5ec3513` |
| `00-21` | **Mocha Latte Decaf** | Decaf Coffee | Coffee | ₱160.00 | ₱80.00 | 50% | 40 | 10 | Active | `a27b17a3-01cf-4183-bb20-579c1bf1c157` |
| `00-22` | **Choco Hazelnut Decaf** | Decaf Coffee | Coffee | ₱160.00 | ₱80.00 | 50% | 40 | 10 | Active | `392f0829-f6c3-4fe7-80a1-d6e606f62679` |
| `00-23` | **Milk Choco** | Non-Coffee & Tea | Drinks | ₱120.00 | ₱60.00 | 50% | 40 | 10 | Active | `2a4683d1-473b-4a45-baf1-54b07e6a13dd` |
| `00-24` | **Hot Choco** | Non-Coffee & Tea | Drinks | ₱120.00 | ₱60.00 | 50% | 40 | 10 | Active | `86c430f9-a3ef-43df-90a5-e8f0a2f1276c` |
| `00-25` | **Iced Tea** | Non-Coffee & Tea | Drinks | ₱65.00 | ₱32.50 | 50% | 80 | 10 | Active | `a45fd9ee-b217-4233-a26b-4893a08cfdd7` |
| `00-26` | **Lychee Aloe** | Non-Coffee & Tea | Drinks | ₱110.00 | ₱55.00 | 50% | 40 | 10 | Active | `89dd9ac6-a789-4bbd-ba15-875d73061bf4` |
| `00-27` | **Lychee Lemon** | Non-Coffee & Tea | Drinks | ₱110.00 | ₱55.00 | 50% | 40 | 10 | Active | `8fabaf9f-d7f7-407e-bc6e-4ee9310845ba` |
| `00-28` | **Strawberry Sparkle** | Non-Coffee & Tea | Drinks | ₱115.00 | ₱57.50 | 50% | 40 | 10 | Active | `d7dbf41c-0073-436a-bfa0-e6dd6be43efb` |
| `00-29` | **Banana Shake** | Fruit Shakes | Drinks | ₱120.00 | ₱60.00 | 50% | 30 | 10 | Active | `4479c7a1-8e7f-4cbd-ba67-8239765ff000` |
| `00-30` | **Mango Shake** | Fruit Shakes | Drinks | ₱130.00 | ₱65.00 | 50% | 30 | 10 | Active | `88890ce1-36c8-4e59-8ce3-7fba3861694b` |
| `00-31` | **Strawberry Shake** | Fruit Shakes | Drinks | ₱130.00 | ₱65.00 | 50% | 30 | 10 | Active | `d8fd6cd9-852f-4387-ba42-12976c69f06d` |
| `00-32` | **Water** | Beverages & Hydration | Drinks | ₱30.00 | ₱15.00 | 50% | 150 | 10 | Active | `af197263-1185-42ee-84ac-fd5e40c270b3` |
| `00-33` | **Coke** | Beverages & Hydration | Drinks | ₱55.00 | ₱27.50 | 50% | 59 | 10 | Active | `d2f08090-f2bd-4380-b13f-0a2dfc9e6ba2` |
| `00-34` | **Royal** | Beverages & Hydration | Drinks | ₱55.00 | ₱27.50 | 50% | 60 | 10 | Active | `8f7d0acc-25d0-4c36-a19f-7c15e08a58fc` |
| `00-35` | **Sprite** | Beverages & Hydration | Drinks | ₱55.00 | ₱27.50 | 50% | 60 | 10 | Active | `d05c8e98-326e-451f-9429-6aea06a09571` |
| `00-36` | **Coke Zero** | Beverages & Hydration | Drinks | ₱55.00 | ₱27.50 | 50% | 60 | 10 | Active | `da9e547d-f016-4f34-8ca2-45b69a4beb24` |
| `00-37` | **Gatorade Blue** | Beverages & Hydration | Drinks | ₱75.00 | ₱37.50 | 50% | 50 | 10 | Active | `189283f8-b5ad-4daf-8ddd-134aa23b838e` |
| `00-38` | **Gatorade Violet** | Beverages & Hydration | Drinks | ₱75.00 | ₱37.50 | 50% | 50 | 10 | Active | `a24d6ab3-e81d-4a29-b065-c271f82170c5` |
| `00-39` | **Gatorade Red** | Beverages & Hydration | Drinks | ₱75.00 | ₱37.50 | 50% | 50 | 10 | Active | `04a2064b-2b5f-4537-bb91-3710b9777dee` |
| `00-40` | **Pocari** | Beverages & Hydration | Drinks | ₱70.00 | ₱35.00 | 50% | 60 | 10 | Active | `210c3c2e-ac71-4cee-a7b9-cec965a95446` |
| `BW-41` | **Vivo** | Bar Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 10 | 10 | Active | `60df43f9-b8c2-4658-8332-47e3d5866e9e` |
| `BW-42` | **Fresh Milk** | Bar Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 21 | 10 | Active | `c33fd977-57f9-4636-9f3a-dd49f60a1f73` |
| `BW-43` | **Oatside** | Bar Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 15 | 10 | Active | `ee8fbad4-8e40-4fed-83e8-6dda08bfa04f` |
| `BW-44` | **Vanilla Syrup** | Bar Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 5 | 10 | Active | `ba78a6fc-8ceb-42ff-b429-e2fcc307c267` |
| `BW-45` | **Hazelnut Syrup** | Bar Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 6 | 10 | Active | `d180810b-62c1-4809-9f1c-61ef2f009c06` |
| `BW-46` | **French Vanilla Syrup** | Bar Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 6 | 10 | Active | `c13cd4d9-477e-4098-b642-1d690887d51d` |
| `BW-47` | **Caramel Syrup** | Bar Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 6 | 10 | Active | `68252bdc-6339-46e0-b996-b6bbf8a8205a` |
| `BW-48` | **Chocolate Syrup** | Bar Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 5 | 10 | Active | `c46acdc6-cf99-422e-af63-8f1af3673e08` |
| `BW-49` | **Lychee** | Bar Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 10 | 10 | Active | `48022483-3229-4df2-bde3-fd0331892b85` |
| `BW-50` | **Condensed** | Bar Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 24 | 10 | Active | `30e3cc60-64b6-4a3a-b5e9-ae4513980def` |
| `K00-01` | **Baconsilog** | Silog Meals | Food | ₱140.00 | ₱70.00 | 50% | 30 | 10 | Active | `fd16fb52-910d-4a37-b9a0-92f956d596aa` |
| `K00-02` | **Bangsilog** | Silog Meals | Food | ₱155.00 | ₱77.50 | 50% | 30 | 10 | Active | `4903241b-358d-4f72-9f3a-7e57dce14cef` |
| `K00-03` | **Chickensilog** | Silog Meals | Food | ₱150.00 | ₱75.00 | 50% | 30 | 10 | Active | `acde9161-2a05-4c3a-b0c7-67797339d13a` |
| `K00-04` | **Cornsilog** | Silog Meals | Food | ₱130.00 | ₱65.00 | 50% | 30 | 10 | Active | `82ad034b-919a-4934-891e-1301b7221787` |
| `K00-05` | **Hotsilog** | Silog Meals | Food | ₱120.00 | ₱60.00 | 50% | 30 | 10 | Active | `973f9ab4-bc52-4476-9d0d-5b658746d734` |
| `K00-06` | **Liemposilog** | Silog Meals | Food | ₱165.00 | ₱82.50 | 50% | 30 | 10 | Active | `28b0281e-313c-469a-a059-dac398ff018d` |
| `K00-07` | **Garlic Longsilog** | Silog Meals | Food | ₱140.00 | ₱70.00 | 50% | 29 | 10 | Active | `a4fbb946-e566-4150-9f8f-5acf2768e215` |
| `K00-08` | **Sweet Longsilog** | Silog Meals | Food | ₱140.00 | ₱70.00 | 50% | 30 | 10 | Active | `7ebd1d03-0b1e-4e84-9d1c-9664ddb1841e` |
| `K00-09` | **Tapsilog** | Silog Meals | Food | ₱160.00 | ₱80.00 | 50% | 31 | 10 | Active | `4c0d21f7-6b3c-4a7a-9c2d-6c3df5cfc1fc` |
| `K00-10` | **Tocilog** | Silog Meals | Food | ₱145.00 | ₱72.50 | 50% | 27 | 10 | Active | `8b929727-6483-41cb-9f6d-63b2e88b90dc` |
| `K00-11` | **Spamsilog** | Silog Meals | Food | ₱145.00 | ₱72.50 | 50% | 30 | 10 | Active | `6da38a3d-9baa-4453-9121-d0a6132915a8` |
| `K00-12` | **Beef Nachos** | Snacks & Dimsum | Food | ₱150.00 | ₱75.00 | 50% | 23 | 10 | Active | `53a0e2d1-7368-46d1-bb26-7f758d7554fd` |
| `K00-13` | **Toge** | Snacks & Dimsum | Food | ₱65.00 | ₱32.50 | 50% | 27 | 10 | Active | `6d69cd0c-7ff8-4efc-b3ee-bb1ae80642e1` |
| `K00-14` | **Fries** | Snacks & Dimsum | Food | ₱90.00 | ₱45.00 | 50% | 38 | 10 | Active | `b7a11614-a94f-4e97-8a70-60bafcdadeaf` |
| `K00-15` | **Pancit Canton Sweet & Spicy** | Noodles & Pasta | Food | ₱50.00 | ₱25.00 | 50% | 50 | 10 | Active | `07a5d27d-4695-4c06-81c2-c958eb62e097` |
| `K00-16` | **Pancit Canton Chilimansi** | Noodles & Pasta | Food | ₱50.00 | ₱25.00 | 50% | 50 | 10 | Active | `f6dacb8d-8bf0-4870-9165-eaf0643d7195` |
| `K00-17` | **Pancit Canton Calamansi** | Noodles & Pasta | Food | ₱50.00 | ₱25.00 | 50% | 50 | 10 | Active | `095ea22a-a66b-4927-8609-5d7065b79018` |
| `K00-18` | **Pancit Canton Hot & Spicy** | Noodles & Pasta | Food | ₱50.00 | ₱25.00 | 50% | 50 | 10 | Active | `ca72cba1-b801-4a25-8254-c8eb63353c0a` |
| `K00-19` | **Pancit Canton Original** | Noodles & Pasta | Food | ₱50.00 | ₱25.00 | 50% | 50 | 10 | Active | `6a1c184d-f98c-4169-9b90-06b0c6ad67b9` |
| `K00-20` | **Egg** | Rice & Add-ons | Food | ₱20.00 | ₱10.00 | 50% | 100 | 10 | Active | `4831bd07-70ff-472c-84a4-c95b7a3c5e6d` |
| `K00-21` | **White Rice** | Rice & Add-ons | Food | ₱25.00 | ₱12.50 | 50% | 98 | 10 | Active | `1879a9a2-8fa7-441c-85e8-b2f2853a35d7` |
| `K00-22` | **Garlic Rice** | Rice & Add-ons | Food | ₱30.00 | ₱15.00 | 50% | 100 | 10 | Active | `350c95d2-6b65-4748-a2da-c44312c6281c` |
| `K00-23` | **Siomai Pork** | Snacks & Dimsum | Food | ₱70.00 | ₱35.00 | 50% | 39 | 10 | Active | `24a2e369-ce0b-4a8c-ada9-ae17a7ad3f9c` |
| `K00-24` | **Siomai Chicken** | Snacks & Dimsum | Food | ₱70.00 | ₱35.00 | 50% | 39 | 10 | Active | `09ce6001-acd0-4209-82c2-6c7da2e7f65d` |
| `K00-25` | **Siomai Beef** | Snacks & Dimsum | Food | ₱75.00 | ₱37.50 | 50% | 38 | 10 | Active | `c144a422-b7b0-4be7-b296-ff65623dfa5c` |
| `K00-26` | **Siomai Japanese** | Snacks & Dimsum | Food | ₱85.00 | ₱42.50 | 50% | 37 | 10 | Active | `5a023b9a-6c7d-4a2f-afc2-d8660eaa252b` |
| `K00-27` | **Siopao** | Snacks & Dimsum | Food | ₱70.00 | ₱35.00 | 50% | 24 | 10 | Active | `d269168c-00ca-40d1-ba5d-f2ffb82e5008` |
| `K00-28` | **Spaghetti Longganisa** | Noodles & Pasta | Food | ₱140.00 | ₱70.00 | 50% | 25 | 10 | Active | `f6e7f897-a840-4d1a-82f1-705b9070fdef` |
| `K00-29` | **Spaghetti Meatballs** | Noodles & Pasta | Food | ₱150.00 | ₱75.00 | 50% | 25 | 10 | Active | `f64226f3-e931-40a3-a91b-e7f19668341e` |
| `K00-30` | **Pizza** | Noodles & Pasta | Food | ₱240.00 | ₱120.00 | 50% | 20 | 10 | Active | `890a1a5d-8694-401d-b1f0-65abb3ef4b3b` |
| `KW-30` | **Cheese Powder** | Kitchen Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 10 | 10 | Active | `c699465d-dab2-4c80-b7b4-f02925a283d4` |
| `KW-31` | **BBQ Powder** | Kitchen Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 10 | 10 | Active | `dc4becb0-ffc4-4e21-a64c-6515a8f3f3b4` |
| `KW-32` | **Sour Cream Powder** | Kitchen Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 10 | 10 | Active | `09103955-d9ce-421c-a932-bf5d224e0def` |
| `KW-33` | **Cucumber** | Kitchen Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 15 | 10 | Active | `70001575-ac70-4c43-ab00-46ecc2535471` |
| `KW-34` | **Tomato** | Kitchen Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 15 | 10 | Active | `76ba413e-b87d-4d72-acd4-4c060e04c064` |
| `KW-35` | **Eden Cheese** | Kitchen Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 12 | 10 | Active | `54ef0dc3-f602-4888-922c-095923584c65` |
| `KW-36` | **Evap** | Kitchen Supplies | Supplies | ₱0.00 | ₱0.00 | 0% | 20 | 10 | Active | `5f62e485-727c-4fa0-bd35-b6716b0c7ee5` |

---

## 5. Ready-to-Use Migration Payloads

### 5.1 JSON Migration Payload

Save this data as `pos_catalog.json` or import directly via REST API:

```json
{
  "version": "1.0.0",
  "exported_at": "2026-09-21T00:00:00Z",
  "facility": "C&J's Events Place & Sports Arena",
  "total_categories": 11,
  "total_products": 87,
  "categories": [
    {
      "id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "name": "Coffee",
      "slug": "coffee",
      "department": "Coffee",
      "description": "Handcrafted espresso and caffeinated specialty drinks",
      "display_order": 1,
      "is_active": true
    },
    {
      "id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "name": "Decaf Coffee",
      "slug": "decaf-coffee",
      "department": "Coffee",
      "description": "Decaffeinated espresso and specialty lattes",
      "display_order": 2,
      "is_active": true
    },
    {
      "id": "aebabe08-d448-4b94-8f1b-b4e821ebb85f",
      "name": "Non-Coffee & Tea",
      "slug": "non-coffee-tea",
      "department": "Drinks",
      "description": "Hot & iced chocolate, teas, and refreshers",
      "display_order": 3,
      "is_active": true
    },
    {
      "id": "8f978f99-acb0-4fc2-92e3-971d314c971e",
      "name": "Fruit Shakes",
      "slug": "fruit-shakes",
      "department": "Drinks",
      "description": "Fresh fruit blended shakes",
      "display_order": 4,
      "is_active": true
    },
    {
      "id": "915e6f8f-a533-4bbd-9cc6-1b10f65fa80a",
      "name": "Beverages & Hydration",
      "slug": "beverages-hydration",
      "department": "Drinks",
      "description": "Bottled water, sodas, Pocari Sweat, and Gatorade",
      "display_order": 5,
      "is_active": true
    },
    {
      "id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "name": "Silog Meals",
      "slug": "silog-meals",
      "department": "Food",
      "description": "All-day breakfast meals served with garlic rice & egg",
      "display_order": 6,
      "is_active": true
    },
    {
      "id": "c29fd4d3-ee90-4271-ad3d-8f8a41ded74b",
      "name": "Snacks & Dimsum",
      "slug": "snacks-dimsum",
      "department": "Food",
      "description": "Nachos, fries, toge, siomai varieties, and siopao",
      "display_order": 7,
      "is_active": true
    },
    {
      "id": "a65c4cd0-4828-4ac4-b6fd-10af2a576bc1",
      "name": "Noodles & Pasta",
      "slug": "noodles-pasta",
      "department": "Food",
      "description": "Pancit Canton varieties, spaghetti, and pizza",
      "display_order": 8,
      "is_active": true
    },
    {
      "id": "723f38c2-5cc2-4df5-97f9-18fefa0d2705",
      "name": "Rice & Add-ons",
      "slug": "rice-addons",
      "department": "Food",
      "description": "Extra rice and sunny side up egg",
      "display_order": 9,
      "is_active": true
    },
    {
      "id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "name": "Bar Supplies",
      "slug": "bar-supplies",
      "department": "Supplies",
      "description": "Bar syrups, dairy, and weekly bar consumables",
      "display_order": 10,
      "is_active": true
    },
    {
      "id": "3fb61468-d49b-4638-bf99-fcec95841e47",
      "name": "Kitchen Supplies",
      "slug": "kitchen-supplies",
      "department": "Supplies",
      "description": "Kitchen seasoning powders, produce, and dairy",
      "display_order": 11,
      "is_active": true
    }
  ],
  "products": [
    {
      "id": "6979df8e-3d00-4aa1-9e0e-e5536a1ce6c4",
      "sku": "00-01",
      "name": "Long Black",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 110,
      "cost_price": 55,
      "stock_level": 44,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "28d0f9f0-0d86-46a1-83ba-978bdedac326",
      "sku": "00-02",
      "name": "Capuccino",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 130,
      "cost_price": 65,
      "stock_level": 49,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "0e86ff8d-70f3-4a9c-ba57-0c5ae41915de",
      "sku": "00-03",
      "name": "Flat White",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 135,
      "cost_price": 67.5,
      "stock_level": 47,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "e972ad24-5be1-4fab-9136-626e6c2b3591",
      "sku": "00-04",
      "name": "Spanish Latte",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 145,
      "cost_price": 72.5,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "b67b6d5d-11cc-470b-9526-dc177a8a4c10",
      "sku": "00-05",
      "name": "Seasalt Latte",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 150,
      "cost_price": 75,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "1c73ec74-2cad-4950-a543-d097f9651595",
      "sku": "00-06",
      "name": "French Vanilla",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 145,
      "cost_price": 72.5,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "8a076bfa-e61d-4e8e-a1d0-0b63d5750d1a",
      "sku": "00-07",
      "name": "Caramel Macchiato",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 150,
      "cost_price": 75,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "44a0d096-e68b-431a-a2b5-b7c764fa0d17",
      "sku": "00-08",
      "name": "Salted Caramel",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 145,
      "cost_price": 72.5,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "9dc8f952-31a4-47e3-8e7a-c99b1f2bd03e",
      "sku": "00-09",
      "name": "Brown Sugar Latte",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 145,
      "cost_price": 72.5,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "8f9e1a52-59f6-4a00-8d59-ae80825eea57",
      "sku": "00-10",
      "name": "Mocha Latte",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 150,
      "cost_price": 75,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "808b0512-e6da-4bc2-9946-40bf6fc271bf",
      "sku": "00-11",
      "name": "Choco Hazelnut",
      "category": "Coffee",
      "category_id": "ad2db960-6fcb-4972-807c-7a82a0eaef62",
      "department": "Coffee",
      "price": 150,
      "cost_price": 75,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "65b02d09-0d06-4787-9b71-1aa6093ec9e0",
      "sku": "00-12",
      "name": "Americano Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 120,
      "cost_price": 60,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "bd391f2f-4914-4a2a-83d7-3f4638e08294",
      "sku": "00-13",
      "name": "Flat White Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 145,
      "cost_price": 72.5,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "a2b05a74-58b0-4b34-af46-3ca2f8605cc8",
      "sku": "00-14",
      "name": "Capuccino Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 140,
      "cost_price": 70,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "ce3982e0-cf51-4c17-b2ab-3e4a776b7750",
      "sku": "00-15",
      "name": "Spanish Latte Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 155,
      "cost_price": 77.5,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "22d879a6-8c1c-4836-a890-082a760cc4a4",
      "sku": "00-16",
      "name": "French Vanilla Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 155,
      "cost_price": 77.5,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "03a0f2b8-018e-4e22-b18d-b70d5db37bc4",
      "sku": "00-17",
      "name": "Caramel Macchiato Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 160,
      "cost_price": 80,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "df13732c-2a5c-4dc6-a617-66088a3496a5",
      "sku": "00-18",
      "name": "Salted Caramel Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 155,
      "cost_price": 77.5,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "ff3dc6b9-eab8-4d84-b5de-2d75ca4f24ff",
      "sku": "00-19",
      "name": "Brown Sugar Latte Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 155,
      "cost_price": 77.5,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "0543de7a-83b8-4057-926f-8a7fa5ec3513",
      "sku": "00-20",
      "name": "Seasalt Butterscotch Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 165,
      "cost_price": 82.5,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "a27b17a3-01cf-4183-bb20-579c1bf1c157",
      "sku": "00-21",
      "name": "Mocha Latte Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 160,
      "cost_price": 80,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "392f0829-f6c3-4fe7-80a1-d6e606f62679",
      "sku": "00-22",
      "name": "Choco Hazelnut Decaf",
      "category": "Decaf Coffee",
      "category_id": "665f3975-2c1c-4fc3-999f-f0facb9a44dd",
      "department": "Coffee",
      "price": 160,
      "cost_price": 80,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "2a4683d1-473b-4a45-baf1-54b07e6a13dd",
      "sku": "00-23",
      "name": "Milk Choco",
      "category": "Non-Coffee & Tea",
      "category_id": "aebabe08-d448-4b94-8f1b-b4e821ebb85f",
      "department": "Drinks",
      "price": 120,
      "cost_price": 60,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "86c430f9-a3ef-43df-90a5-e8f0a2f1276c",
      "sku": "00-24",
      "name": "Hot Choco",
      "category": "Non-Coffee & Tea",
      "category_id": "aebabe08-d448-4b94-8f1b-b4e821ebb85f",
      "department": "Drinks",
      "price": 120,
      "cost_price": 60,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "a45fd9ee-b217-4233-a26b-4893a08cfdd7",
      "sku": "00-25",
      "name": "Iced Tea",
      "category": "Non-Coffee & Tea",
      "category_id": "aebabe08-d448-4b94-8f1b-b4e821ebb85f",
      "department": "Drinks",
      "price": 65,
      "cost_price": 32.5,
      "stock_level": 80,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "89dd9ac6-a789-4bbd-ba15-875d73061bf4",
      "sku": "00-26",
      "name": "Lychee Aloe",
      "category": "Non-Coffee & Tea",
      "category_id": "aebabe08-d448-4b94-8f1b-b4e821ebb85f",
      "department": "Drinks",
      "price": 110,
      "cost_price": 55,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "8fabaf9f-d7f7-407e-bc6e-4ee9310845ba",
      "sku": "00-27",
      "name": "Lychee Lemon",
      "category": "Non-Coffee & Tea",
      "category_id": "aebabe08-d448-4b94-8f1b-b4e821ebb85f",
      "department": "Drinks",
      "price": 110,
      "cost_price": 55,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "d7dbf41c-0073-436a-bfa0-e6dd6be43efb",
      "sku": "00-28",
      "name": "Strawberry Sparkle",
      "category": "Non-Coffee & Tea",
      "category_id": "aebabe08-d448-4b94-8f1b-b4e821ebb85f",
      "department": "Drinks",
      "price": 115,
      "cost_price": 57.5,
      "stock_level": 40,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "4479c7a1-8e7f-4cbd-ba67-8239765ff000",
      "sku": "00-29",
      "name": "Banana Shake",
      "category": "Fruit Shakes",
      "category_id": "8f978f99-acb0-4fc2-92e3-971d314c971e",
      "department": "Drinks",
      "price": 120,
      "cost_price": 60,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "88890ce1-36c8-4e59-8ce3-7fba3861694b",
      "sku": "00-30",
      "name": "Mango Shake",
      "category": "Fruit Shakes",
      "category_id": "8f978f99-acb0-4fc2-92e3-971d314c971e",
      "department": "Drinks",
      "price": 130,
      "cost_price": 65,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "d8fd6cd9-852f-4387-ba42-12976c69f06d",
      "sku": "00-31",
      "name": "Strawberry Shake",
      "category": "Fruit Shakes",
      "category_id": "8f978f99-acb0-4fc2-92e3-971d314c971e",
      "department": "Drinks",
      "price": 130,
      "cost_price": 65,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "af197263-1185-42ee-84ac-fd5e40c270b3",
      "sku": "00-32",
      "name": "Water",
      "category": "Beverages & Hydration",
      "category_id": "915e6f8f-a533-4bbd-9cc6-1b10f65fa80a",
      "department": "Drinks",
      "price": 30,
      "cost_price": 15,
      "stock_level": 150,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "d2f08090-f2bd-4380-b13f-0a2dfc9e6ba2",
      "sku": "00-33",
      "name": "Coke",
      "category": "Beverages & Hydration",
      "category_id": "915e6f8f-a533-4bbd-9cc6-1b10f65fa80a",
      "department": "Drinks",
      "price": 55,
      "cost_price": 27.5,
      "stock_level": 59,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "8f7d0acc-25d0-4c36-a19f-7c15e08a58fc",
      "sku": "00-34",
      "name": "Royal",
      "category": "Beverages & Hydration",
      "category_id": "915e6f8f-a533-4bbd-9cc6-1b10f65fa80a",
      "department": "Drinks",
      "price": 55,
      "cost_price": 27.5,
      "stock_level": 60,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "d05c8e98-326e-451f-9429-6aea06a09571",
      "sku": "00-35",
      "name": "Sprite",
      "category": "Beverages & Hydration",
      "category_id": "915e6f8f-a533-4bbd-9cc6-1b10f65fa80a",
      "department": "Drinks",
      "price": 55,
      "cost_price": 27.5,
      "stock_level": 60,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "da9e547d-f016-4f34-8ca2-45b69a4beb24",
      "sku": "00-36",
      "name": "Coke Zero",
      "category": "Beverages & Hydration",
      "category_id": "915e6f8f-a533-4bbd-9cc6-1b10f65fa80a",
      "department": "Drinks",
      "price": 55,
      "cost_price": 27.5,
      "stock_level": 60,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "189283f8-b5ad-4daf-8ddd-134aa23b838e",
      "sku": "00-37",
      "name": "Gatorade Blue",
      "category": "Beverages & Hydration",
      "category_id": "915e6f8f-a533-4bbd-9cc6-1b10f65fa80a",
      "department": "Drinks",
      "price": 75,
      "cost_price": 37.5,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "a24d6ab3-e81d-4a29-b065-c271f82170c5",
      "sku": "00-38",
      "name": "Gatorade Violet",
      "category": "Beverages & Hydration",
      "category_id": "915e6f8f-a533-4bbd-9cc6-1b10f65fa80a",
      "department": "Drinks",
      "price": 75,
      "cost_price": 37.5,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "04a2064b-2b5f-4537-bb91-3710b9777dee",
      "sku": "00-39",
      "name": "Gatorade Red",
      "category": "Beverages & Hydration",
      "category_id": "915e6f8f-a533-4bbd-9cc6-1b10f65fa80a",
      "department": "Drinks",
      "price": 75,
      "cost_price": 37.5,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "210c3c2e-ac71-4cee-a7b9-cec965a95446",
      "sku": "00-40",
      "name": "Pocari",
      "category": "Beverages & Hydration",
      "category_id": "915e6f8f-a533-4bbd-9cc6-1b10f65fa80a",
      "department": "Drinks",
      "price": 70,
      "cost_price": 35,
      "stock_level": 60,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "60df43f9-b8c2-4658-8332-47e3d5866e9e",
      "sku": "BW-41",
      "name": "Vivo",
      "category": "Bar Supplies",
      "category_id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 10,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "c33fd977-57f9-4636-9f3a-dd49f60a1f73",
      "sku": "BW-42",
      "name": "Fresh Milk",
      "category": "Bar Supplies",
      "category_id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 21,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "ee8fbad4-8e40-4fed-83e8-6dda08bfa04f",
      "sku": "BW-43",
      "name": "Oatside",
      "category": "Bar Supplies",
      "category_id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 15,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "ba78a6fc-8ceb-42ff-b429-e2fcc307c267",
      "sku": "BW-44",
      "name": "Vanilla Syrup",
      "category": "Bar Supplies",
      "category_id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 5,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "d180810b-62c1-4809-9f1c-61ef2f009c06",
      "sku": "BW-45",
      "name": "Hazelnut Syrup",
      "category": "Bar Supplies",
      "category_id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 6,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "c13cd4d9-477e-4098-b642-1d690887d51d",
      "sku": "BW-46",
      "name": "French Vanilla Syrup",
      "category": "Bar Supplies",
      "category_id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 6,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "68252bdc-6339-46e0-b996-b6bbf8a8205a",
      "sku": "BW-47",
      "name": "Caramel Syrup",
      "category": "Bar Supplies",
      "category_id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 6,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "c46acdc6-cf99-422e-af63-8f1af3673e08",
      "sku": "BW-48",
      "name": "Chocolate Syrup",
      "category": "Bar Supplies",
      "category_id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 5,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "48022483-3229-4df2-bde3-fd0331892b85",
      "sku": "BW-49",
      "name": "Lychee",
      "category": "Bar Supplies",
      "category_id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 10,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "30e3cc60-64b6-4a3a-b5e9-ae4513980def",
      "sku": "BW-50",
      "name": "Condensed",
      "category": "Bar Supplies",
      "category_id": "96a94c7c-0207-4f72-991a-f11677b111cb",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 24,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "fd16fb52-910d-4a37-b9a0-92f956d596aa",
      "sku": "K00-01",
      "name": "Baconsilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 140,
      "cost_price": 70,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "4903241b-358d-4f72-9f3a-7e57dce14cef",
      "sku": "K00-02",
      "name": "Bangsilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 155,
      "cost_price": 77.5,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "acde9161-2a05-4c3a-b0c7-67797339d13a",
      "sku": "K00-03",
      "name": "Chickensilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 150,
      "cost_price": 75,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "82ad034b-919a-4934-891e-1301b7221787",
      "sku": "K00-04",
      "name": "Cornsilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 130,
      "cost_price": 65,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "973f9ab4-bc52-4476-9d0d-5b658746d734",
      "sku": "K00-05",
      "name": "Hotsilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 120,
      "cost_price": 60,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "28b0281e-313c-469a-a059-dac398ff018d",
      "sku": "K00-06",
      "name": "Liemposilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 165,
      "cost_price": 82.5,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "a4fbb946-e566-4150-9f8f-5acf2768e215",
      "sku": "K00-07",
      "name": "Garlic Longsilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 140,
      "cost_price": 70,
      "stock_level": 29,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "7ebd1d03-0b1e-4e84-9d1c-9664ddb1841e",
      "sku": "K00-08",
      "name": "Sweet Longsilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 140,
      "cost_price": 70,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "4c0d21f7-6b3c-4a7a-9c2d-6c3df5cfc1fc",
      "sku": "K00-09",
      "name": "Tapsilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 160,
      "cost_price": 80,
      "stock_level": 31,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "8b929727-6483-41cb-9f6d-63b2e88b90dc",
      "sku": "K00-10",
      "name": "Tocilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 145,
      "cost_price": 72.5,
      "stock_level": 27,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "6da38a3d-9baa-4453-9121-d0a6132915a8",
      "sku": "K00-11",
      "name": "Spamsilog",
      "category": "Silog Meals",
      "category_id": "88a61c9a-7a45-443f-97b5-0492e680fbde",
      "department": "Food",
      "price": 145,
      "cost_price": 72.5,
      "stock_level": 30,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "53a0e2d1-7368-46d1-bb26-7f758d7554fd",
      "sku": "K00-12",
      "name": "Beef Nachos",
      "category": "Snacks & Dimsum",
      "category_id": "c29fd4d3-ee90-4271-ad3d-8f8a41ded74b",
      "department": "Food",
      "price": 150,
      "cost_price": 75,
      "stock_level": 23,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "6d69cd0c-7ff8-4efc-b3ee-bb1ae80642e1",
      "sku": "K00-13",
      "name": "Toge",
      "category": "Snacks & Dimsum",
      "category_id": "c29fd4d3-ee90-4271-ad3d-8f8a41ded74b",
      "department": "Food",
      "price": 65,
      "cost_price": 32.5,
      "stock_level": 27,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "b7a11614-a94f-4e97-8a70-60bafcdadeaf",
      "sku": "K00-14",
      "name": "Fries",
      "category": "Snacks & Dimsum",
      "category_id": "c29fd4d3-ee90-4271-ad3d-8f8a41ded74b",
      "department": "Food",
      "price": 90,
      "cost_price": 45,
      "stock_level": 38,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "07a5d27d-4695-4c06-81c2-c958eb62e097",
      "sku": "K00-15",
      "name": "Pancit Canton Sweet & Spicy",
      "category": "Noodles & Pasta",
      "category_id": "a65c4cd0-4828-4ac4-b6fd-10af2a576bc1",
      "department": "Food",
      "price": 50,
      "cost_price": 25,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "f6dacb8d-8bf0-4870-9165-eaf0643d7195",
      "sku": "K00-16",
      "name": "Pancit Canton Chilimansi",
      "category": "Noodles & Pasta",
      "category_id": "a65c4cd0-4828-4ac4-b6fd-10af2a576bc1",
      "department": "Food",
      "price": 50,
      "cost_price": 25,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "095ea22a-a66b-4927-8609-5d7065b79018",
      "sku": "K00-17",
      "name": "Pancit Canton Calamansi",
      "category": "Noodles & Pasta",
      "category_id": "a65c4cd0-4828-4ac4-b6fd-10af2a576bc1",
      "department": "Food",
      "price": 50,
      "cost_price": 25,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "ca72cba1-b801-4a25-8254-c8eb63353c0a",
      "sku": "K00-18",
      "name": "Pancit Canton Hot & Spicy",
      "category": "Noodles & Pasta",
      "category_id": "a65c4cd0-4828-4ac4-b6fd-10af2a576bc1",
      "department": "Food",
      "price": 50,
      "cost_price": 25,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "6a1c184d-f98c-4169-9b90-06b0c6ad67b9",
      "sku": "K00-19",
      "name": "Pancit Canton Original",
      "category": "Noodles & Pasta",
      "category_id": "a65c4cd0-4828-4ac4-b6fd-10af2a576bc1",
      "department": "Food",
      "price": 50,
      "cost_price": 25,
      "stock_level": 50,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "4831bd07-70ff-472c-84a4-c95b7a3c5e6d",
      "sku": "K00-20",
      "name": "Egg",
      "category": "Rice & Add-ons",
      "category_id": "723f38c2-5cc2-4df5-97f9-18fefa0d2705",
      "department": "Food",
      "price": 20,
      "cost_price": 10,
      "stock_level": 100,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "1879a9a2-8fa7-441c-85e8-b2f2853a35d7",
      "sku": "K00-21",
      "name": "White Rice",
      "category": "Rice & Add-ons",
      "category_id": "723f38c2-5cc2-4df5-97f9-18fefa0d2705",
      "department": "Food",
      "price": 25,
      "cost_price": 12.5,
      "stock_level": 98,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "350c95d2-6b65-4748-a2da-c44312c6281c",
      "sku": "K00-22",
      "name": "Garlic Rice",
      "category": "Rice & Add-ons",
      "category_id": "723f38c2-5cc2-4df5-97f9-18fefa0d2705",
      "department": "Food",
      "price": 30,
      "cost_price": 15,
      "stock_level": 100,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "24a2e369-ce0b-4a8c-ada9-ae17a7ad3f9c",
      "sku": "K00-23",
      "name": "Siomai Pork",
      "category": "Snacks & Dimsum",
      "category_id": "c29fd4d3-ee90-4271-ad3d-8f8a41ded74b",
      "department": "Food",
      "price": 70,
      "cost_price": 35,
      "stock_level": 39,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "09ce6001-acd0-4209-82c2-6c7da2e7f65d",
      "sku": "K00-24",
      "name": "Siomai Chicken",
      "category": "Snacks & Dimsum",
      "category_id": "c29fd4d3-ee90-4271-ad3d-8f8a41ded74b",
      "department": "Food",
      "price": 70,
      "cost_price": 35,
      "stock_level": 39,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "c144a422-b7b0-4be7-b296-ff65623dfa5c",
      "sku": "K00-25",
      "name": "Siomai Beef",
      "category": "Snacks & Dimsum",
      "category_id": "c29fd4d3-ee90-4271-ad3d-8f8a41ded74b",
      "department": "Food",
      "price": 75,
      "cost_price": 37.5,
      "stock_level": 38,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "5a023b9a-6c7d-4a2f-afc2-d8660eaa252b",
      "sku": "K00-26",
      "name": "Siomai Japanese",
      "category": "Snacks & Dimsum",
      "category_id": "c29fd4d3-ee90-4271-ad3d-8f8a41ded74b",
      "department": "Food",
      "price": 85,
      "cost_price": 42.5,
      "stock_level": 37,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "d269168c-00ca-40d1-ba5d-f2ffb82e5008",
      "sku": "K00-27",
      "name": "Siopao",
      "category": "Snacks & Dimsum",
      "category_id": "c29fd4d3-ee90-4271-ad3d-8f8a41ded74b",
      "department": "Food",
      "price": 70,
      "cost_price": 35,
      "stock_level": 24,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "f6e7f897-a840-4d1a-82f1-705b9070fdef",
      "sku": "K00-28",
      "name": "Spaghetti Longganisa",
      "category": "Noodles & Pasta",
      "category_id": "a65c4cd0-4828-4ac4-b6fd-10af2a576bc1",
      "department": "Food",
      "price": 140,
      "cost_price": 70,
      "stock_level": 25,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "f64226f3-e931-40a3-a91b-e7f19668341e",
      "sku": "K00-29",
      "name": "Spaghetti Meatballs",
      "category": "Noodles & Pasta",
      "category_id": "a65c4cd0-4828-4ac4-b6fd-10af2a576bc1",
      "department": "Food",
      "price": 150,
      "cost_price": 75,
      "stock_level": 25,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "890a1a5d-8694-401d-b1f0-65abb3ef4b3b",
      "sku": "K00-30",
      "name": "Pizza",
      "category": "Noodles & Pasta",
      "category_id": "a65c4cd0-4828-4ac4-b6fd-10af2a576bc1",
      "department": "Food",
      "price": 240,
      "cost_price": 120,
      "stock_level": 20,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "c699465d-dab2-4c80-b7b4-f02925a283d4",
      "sku": "KW-30",
      "name": "Cheese Powder",
      "category": "Kitchen Supplies",
      "category_id": "3fb61468-d49b-4638-bf99-fcec95841e47",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 10,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "dc4becb0-ffc4-4e21-a64c-6515a8f3f3b4",
      "sku": "KW-31",
      "name": "BBQ Powder",
      "category": "Kitchen Supplies",
      "category_id": "3fb61468-d49b-4638-bf99-fcec95841e47",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 10,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "09103955-d9ce-421c-a932-bf5d224e0def",
      "sku": "KW-32",
      "name": "Sour Cream Powder",
      "category": "Kitchen Supplies",
      "category_id": "3fb61468-d49b-4638-bf99-fcec95841e47",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 10,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "70001575-ac70-4c43-ab00-46ecc2535471",
      "sku": "KW-33",
      "name": "Cucumber",
      "category": "Kitchen Supplies",
      "category_id": "3fb61468-d49b-4638-bf99-fcec95841e47",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 15,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "76ba413e-b87d-4d72-acd4-4c060e04c064",
      "sku": "KW-34",
      "name": "Tomato",
      "category": "Kitchen Supplies",
      "category_id": "3fb61468-d49b-4638-bf99-fcec95841e47",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 15,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "54ef0dc3-f602-4888-922c-095923584c65",
      "sku": "KW-35",
      "name": "Eden Cheese",
      "category": "Kitchen Supplies",
      "category_id": "3fb61468-d49b-4638-bf99-fcec95841e47",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 12,
      "reorder_threshold": 10,
      "is_active": true
    },
    {
      "id": "5f62e485-727c-4fa0-bd35-b6716b0c7ee5",
      "sku": "KW-36",
      "name": "Evap",
      "category": "Kitchen Supplies",
      "category_id": "3fb61468-d49b-4638-bf99-fcec95841e47",
      "department": "Supplies",
      "price": 0,
      "cost_price": 0,
      "stock_level": 20,
      "reorder_threshold": 10,
      "is_active": true
    }
  ]
}
```

---

### 5.2 PostgreSQL / Supabase SQL Migration Script

Execute this SQL script to create schema and populate all 11 categories and 87 products idempotently:

```sql
-- 1. Create Tables if not already created
CREATE TABLE IF NOT EXISTS public.pos_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.pos_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku TEXT UNIQUE,
  category_id UUID REFERENCES public.pos_categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  cost_price NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  stock_level INTEGER NOT NULL DEFAULT 0,
  reorder_threshold INTEGER NOT NULL DEFAULT 10,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Seed Categories
INSERT INTO public.pos_categories (id, name, slug, description, display_order, is_active)
VALUES
  ('ad2db960-6fcb-4972-807c-7a82a0eaef62', 'Coffee', 'coffee', 'Handcrafted espresso and caffeinated specialty drinks', 1, true),
  ('665f3975-2c1c-4fc3-999f-f0facb9a44dd', 'Decaf Coffee', 'decaf-coffee', 'Decaffeinated espresso and specialty lattes', 2, true),
  ('aebabe08-d448-4b94-8f1b-b4e821ebb85f', 'Non-Coffee & Tea', 'non-coffee-tea', 'Hot & iced chocolate, teas, and refreshers', 3, true),
  ('8f978f99-acb0-4fc2-92e3-971d314c971e', 'Fruit Shakes', 'fruit-shakes', 'Fresh fruit blended shakes', 4, true),
  ('915e6f8f-a533-4bbd-9cc6-1b10f65fa80a', 'Beverages & Hydration', 'beverages-hydration', 'Bottled water, sodas, Pocari Sweat, and Gatorade', 5, true),
  ('88a61c9a-7a45-443f-97b5-0492e680fbde', 'Silog Meals', 'silog-meals', 'All-day breakfast meals served with garlic rice & egg', 6, true),
  ('c29fd4d3-ee90-4271-ad3d-8f8a41ded74b', 'Snacks & Dimsum', 'snacks-dimsum', 'Nachos, fries, toge, siomai varieties, and siopao', 7, true),
  ('a65c4cd0-4828-4ac4-b6fd-10af2a576bc1', 'Noodles & Pasta', 'noodles-pasta', 'Pancit Canton varieties, spaghetti, and pizza', 8, true),
  ('723f38c2-5cc2-4df5-97f9-18fefa0d2705', 'Rice & Add-ons', 'rice-addons', 'Extra rice and sunny side up egg', 9, true),
  ('96a94c7c-0207-4f72-991a-f11677b111cb', 'Bar Supplies', 'bar-supplies', 'Bar syrups, dairy, and weekly bar consumables', 10, true),
  ('3fb61468-d49b-4638-bf99-fcec95841e47', 'Kitchen Supplies', 'kitchen-supplies', 'Kitchen seasoning powders, produce, and dairy', 11, true)
ON CONFLICT (name) DO UPDATE SET
  slug = EXCLUDED.slug,
  description = EXCLUDED.description,
  display_order = EXCLUDED.display_order,
  is_active = EXCLUDED.is_active;

-- 3. Seed Products
INSERT INTO public.pos_products (id, sku, name, category, category_id, price, cost_price, stock_level, reorder_threshold, is_active)
VALUES
  ('6979df8e-3d00-4aa1-9e0e-e5536a1ce6c4', '00-01', 'Long Black', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 110.00, 55.00, 44, 10, true),
  ('28d0f9f0-0d86-46a1-83ba-978bdedac326', '00-02', 'Capuccino', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 130.00, 65.00, 49, 10, true),
  ('0e86ff8d-70f3-4a9c-ba57-0c5ae41915de', '00-03', 'Flat White', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 135.00, 67.50, 47, 10, true),
  ('e972ad24-5be1-4fab-9136-626e6c2b3591', '00-04', 'Spanish Latte', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 145.00, 72.50, 50, 10, true),
  ('b67b6d5d-11cc-470b-9526-dc177a8a4c10', '00-05', 'Seasalt Latte', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 150.00, 75.00, 50, 10, true),
  ('1c73ec74-2cad-4950-a543-d097f9651595', '00-06', 'French Vanilla', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 145.00, 72.50, 50, 10, true),
  ('8a076bfa-e61d-4e8e-a1d0-0b63d5750d1a', '00-07', 'Caramel Macchiato', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 150.00, 75.00, 50, 10, true),
  ('44a0d096-e68b-431a-a2b5-b7c764fa0d17', '00-08', 'Salted Caramel', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 145.00, 72.50, 50, 10, true),
  ('9dc8f952-31a4-47e3-8e7a-c99b1f2bd03e', '00-09', 'Brown Sugar Latte', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 145.00, 72.50, 50, 10, true),
  ('8f9e1a52-59f6-4a00-8d59-ae80825eea57', '00-10', 'Mocha Latte', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 150.00, 75.00, 50, 10, true),
  ('808b0512-e6da-4bc2-9946-40bf6fc271bf', '00-11', 'Choco Hazelnut', 'Coffee', 'ad2db960-6fcb-4972-807c-7a82a0eaef62', 150.00, 75.00, 50, 10, true),
  ('65b02d09-0d06-4787-9b71-1aa6093ec9e0', '00-12', 'Americano Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 120.00, 60.00, 40, 10, true),
  ('bd391f2f-4914-4a2a-83d7-3f4638e08294', '00-13', 'Flat White Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 145.00, 72.50, 40, 10, true),
  ('a2b05a74-58b0-4b34-af46-3ca2f8605cc8', '00-14', 'Capuccino Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 140.00, 70.00, 40, 10, true),
  ('ce3982e0-cf51-4c17-b2ab-3e4a776b7750', '00-15', 'Spanish Latte Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 155.00, 77.50, 40, 10, true),
  ('22d879a6-8c1c-4836-a890-082a760cc4a4', '00-16', 'French Vanilla Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 155.00, 77.50, 40, 10, true),
  ('03a0f2b8-018e-4e22-b18d-b70d5db37bc4', '00-17', 'Caramel Macchiato Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 160.00, 80.00, 40, 10, true),
  ('df13732c-2a5c-4dc6-a617-66088a3496a5', '00-18', 'Salted Caramel Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 155.00, 77.50, 40, 10, true),
  ('ff3dc6b9-eab8-4d84-b5de-2d75ca4f24ff', '00-19', 'Brown Sugar Latte Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 155.00, 77.50, 40, 10, true),
  ('0543de7a-83b8-4057-926f-8a7fa5ec3513', '00-20', 'Seasalt Butterscotch Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 165.00, 82.50, 40, 10, true),
  ('a27b17a3-01cf-4183-bb20-579c1bf1c157', '00-21', 'Mocha Latte Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 160.00, 80.00, 40, 10, true),
  ('392f0829-f6c3-4fe7-80a1-d6e606f62679', '00-22', 'Choco Hazelnut Decaf', 'Decaf Coffee', '665f3975-2c1c-4fc3-999f-f0facb9a44dd', 160.00, 80.00, 40, 10, true),
  ('2a4683d1-473b-4a45-baf1-54b07e6a13dd', '00-23', 'Milk Choco', 'Non-Coffee & Tea', 'aebabe08-d448-4b94-8f1b-b4e821ebb85f', 120.00, 60.00, 40, 10, true),
  ('86c430f9-a3ef-43df-90a5-e8f0a2f1276c', '00-24', 'Hot Choco', 'Non-Coffee & Tea', 'aebabe08-d448-4b94-8f1b-b4e821ebb85f', 120.00, 60.00, 40, 10, true),
  ('a45fd9ee-b217-4233-a26b-4893a08cfdd7', '00-25', 'Iced Tea', 'Non-Coffee & Tea', 'aebabe08-d448-4b94-8f1b-b4e821ebb85f', 65.00, 32.50, 80, 10, true),
  ('89dd9ac6-a789-4bbd-ba15-875d73061bf4', '00-26', 'Lychee Aloe', 'Non-Coffee & Tea', 'aebabe08-d448-4b94-8f1b-b4e821ebb85f', 110.00, 55.00, 40, 10, true),
  ('8fabaf9f-d7f7-407e-bc6e-4ee9310845ba', '00-27', 'Lychee Lemon', 'Non-Coffee & Tea', 'aebabe08-d448-4b94-8f1b-b4e821ebb85f', 110.00, 55.00, 40, 10, true),
  ('d7dbf41c-0073-436a-bfa0-e6dd6be43efb', '00-28', 'Strawberry Sparkle', 'Non-Coffee & Tea', 'aebabe08-d448-4b94-8f1b-b4e821ebb85f', 115.00, 57.50, 40, 10, true),
  ('4479c7a1-8e7f-4cbd-ba67-8239765ff000', '00-29', 'Banana Shake', 'Fruit Shakes', '8f978f99-acb0-4fc2-92e3-971d314c971e', 120.00, 60.00, 30, 10, true),
  ('88890ce1-36c8-4e59-8ce3-7fba3861694b', '00-30', 'Mango Shake', 'Fruit Shakes', '8f978f99-acb0-4fc2-92e3-971d314c971e', 130.00, 65.00, 30, 10, true),
  ('d8fd6cd9-852f-4387-ba42-12976c69f06d', '00-31', 'Strawberry Shake', 'Fruit Shakes', '8f978f99-acb0-4fc2-92e3-971d314c971e', 130.00, 65.00, 30, 10, true),
  ('af197263-1185-42ee-84ac-fd5e40c270b3', '00-32', 'Water', 'Beverages & Hydration', '915e6f8f-a533-4bbd-9cc6-1b10f65fa80a', 30.00, 15.00, 150, 10, true),
  ('d2f08090-f2bd-4380-b13f-0a2dfc9e6ba2', '00-33', 'Coke', 'Beverages & Hydration', '915e6f8f-a533-4bbd-9cc6-1b10f65fa80a', 55.00, 27.50, 59, 10, true),
  ('8f7d0acc-25d0-4c36-a19f-7c15e08a58fc', '00-34', 'Royal', 'Beverages & Hydration', '915e6f8f-a533-4bbd-9cc6-1b10f65fa80a', 55.00, 27.50, 60, 10, true),
  ('d05c8e98-326e-451f-9429-6aea06a09571', '00-35', 'Sprite', 'Beverages & Hydration', '915e6f8f-a533-4bbd-9cc6-1b10f65fa80a', 55.00, 27.50, 60, 10, true),
  ('da9e547d-f016-4f34-8ca2-45b69a4beb24', '00-36', 'Coke Zero', 'Beverages & Hydration', '915e6f8f-a533-4bbd-9cc6-1b10f65fa80a', 55.00, 27.50, 60, 10, true),
  ('189283f8-b5ad-4daf-8ddd-134aa23b838e', '00-37', 'Gatorade Blue', 'Beverages & Hydration', '915e6f8f-a533-4bbd-9cc6-1b10f65fa80a', 75.00, 37.50, 50, 10, true),
  ('a24d6ab3-e81d-4a29-b065-c271f82170c5', '00-38', 'Gatorade Violet', 'Beverages & Hydration', '915e6f8f-a533-4bbd-9cc6-1b10f65fa80a', 75.00, 37.50, 50, 10, true),
  ('04a2064b-2b5f-4537-bb91-3710b9777dee', '00-39', 'Gatorade Red', 'Beverages & Hydration', '915e6f8f-a533-4bbd-9cc6-1b10f65fa80a', 75.00, 37.50, 50, 10, true),
  ('210c3c2e-ac71-4cee-a7b9-cec965a95446', '00-40', 'Pocari', 'Beverages & Hydration', '915e6f8f-a533-4bbd-9cc6-1b10f65fa80a', 70.00, 35.00, 60, 10, true),
  ('60df43f9-b8c2-4658-8332-47e3d5866e9e', 'BW-41', 'Vivo', 'Bar Supplies', '96a94c7c-0207-4f72-991a-f11677b111cb', 0.00, 0.00, 10, 10, true),
  ('c33fd977-57f9-4636-9f3a-dd49f60a1f73', 'BW-42', 'Fresh Milk', 'Bar Supplies', '96a94c7c-0207-4f72-991a-f11677b111cb', 0.00, 0.00, 21, 10, true),
  ('ee8fbad4-8e40-4fed-83e8-6dda08bfa04f', 'BW-43', 'Oatside', 'Bar Supplies', '96a94c7c-0207-4f72-991a-f11677b111cb', 0.00, 0.00, 15, 10, true),
  ('ba78a6fc-8ceb-42ff-b429-e2fcc307c267', 'BW-44', 'Vanilla Syrup', 'Bar Supplies', '96a94c7c-0207-4f72-991a-f11677b111cb', 0.00, 0.00, 5, 10, true),
  ('d180810b-62c1-4809-9f1c-61ef2f009c06', 'BW-45', 'Hazelnut Syrup', 'Bar Supplies', '96a94c7c-0207-4f72-991a-f11677b111cb', 0.00, 0.00, 6, 10, true),
  ('c13cd4d9-477e-4098-b642-1d690887d51d', 'BW-46', 'French Vanilla Syrup', 'Bar Supplies', '96a94c7c-0207-4f72-991a-f11677b111cb', 0.00, 0.00, 6, 10, true),
  ('68252bdc-6339-46e0-b996-b6bbf8a8205a', 'BW-47', 'Caramel Syrup', 'Bar Supplies', '96a94c7c-0207-4f72-991a-f11677b111cb', 0.00, 0.00, 6, 10, true),
  ('c46acdc6-cf99-422e-af63-8f1af3673e08', 'BW-48', 'Chocolate Syrup', 'Bar Supplies', '96a94c7c-0207-4f72-991a-f11677b111cb', 0.00, 0.00, 5, 10, true),
  ('48022483-3229-4df2-bde3-fd0331892b85', 'BW-49', 'Lychee', 'Bar Supplies', '96a94c7c-0207-4f72-991a-f11677b111cb', 0.00, 0.00, 10, 10, true),
  ('30e3cc60-64b6-4a3a-b5e9-ae4513980def', 'BW-50', 'Condensed', 'Bar Supplies', '96a94c7c-0207-4f72-991a-f11677b111cb', 0.00, 0.00, 24, 10, true),
  ('fd16fb52-910d-4a37-b9a0-92f956d596aa', 'K00-01', 'Baconsilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 140.00, 70.00, 30, 10, true),
  ('4903241b-358d-4f72-9f3a-7e57dce14cef', 'K00-02', 'Bangsilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 155.00, 77.50, 30, 10, true),
  ('acde9161-2a05-4c3a-b0c7-67797339d13a', 'K00-03', 'Chickensilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 150.00, 75.00, 30, 10, true),
  ('82ad034b-919a-4934-891e-1301b7221787', 'K00-04', 'Cornsilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 130.00, 65.00, 30, 10, true),
  ('973f9ab4-bc52-4476-9d0d-5b658746d734', 'K00-05', 'Hotsilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 120.00, 60.00, 30, 10, true),
  ('28b0281e-313c-469a-a059-dac398ff018d', 'K00-06', 'Liemposilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 165.00, 82.50, 30, 10, true),
  ('a4fbb946-e566-4150-9f8f-5acf2768e215', 'K00-07', 'Garlic Longsilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 140.00, 70.00, 29, 10, true),
  ('7ebd1d03-0b1e-4e84-9d1c-9664ddb1841e', 'K00-08', 'Sweet Longsilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 140.00, 70.00, 30, 10, true),
  ('4c0d21f7-6b3c-4a7a-9c2d-6c3df5cfc1fc', 'K00-09', 'Tapsilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 160.00, 80.00, 31, 10, true),
  ('8b929727-6483-41cb-9f6d-63b2e88b90dc', 'K00-10', 'Tocilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 145.00, 72.50, 27, 10, true),
  ('6da38a3d-9baa-4453-9121-d0a6132915a8', 'K00-11', 'Spamsilog', 'Silog Meals', '88a61c9a-7a45-443f-97b5-0492e680fbde', 145.00, 72.50, 30, 10, true),
  ('53a0e2d1-7368-46d1-bb26-7f758d7554fd', 'K00-12', 'Beef Nachos', 'Snacks & Dimsum', 'c29fd4d3-ee90-4271-ad3d-8f8a41ded74b', 150.00, 75.00, 23, 10, true),
  ('6d69cd0c-7ff8-4efc-b3ee-bb1ae80642e1', 'K00-13', 'Toge', 'Snacks & Dimsum', 'c29fd4d3-ee90-4271-ad3d-8f8a41ded74b', 65.00, 32.50, 27, 10, true),
  ('b7a11614-a94f-4e97-8a70-60bafcdadeaf', 'K00-14', 'Fries', 'Snacks & Dimsum', 'c29fd4d3-ee90-4271-ad3d-8f8a41ded74b', 90.00, 45.00, 38, 10, true),
  ('07a5d27d-4695-4c06-81c2-c958eb62e097', 'K00-15', 'Pancit Canton Sweet & Spicy', 'Noodles & Pasta', 'a65c4cd0-4828-4ac4-b6fd-10af2a576bc1', 50.00, 25.00, 50, 10, true),
  ('f6dacb8d-8bf0-4870-9165-eaf0643d7195', 'K00-16', 'Pancit Canton Chilimansi', 'Noodles & Pasta', 'a65c4cd0-4828-4ac4-b6fd-10af2a576bc1', 50.00, 25.00, 50, 10, true),
  ('095ea22a-a66b-4927-8609-5d7065b79018', 'K00-17', 'Pancit Canton Calamansi', 'Noodles & Pasta', 'a65c4cd0-4828-4ac4-b6fd-10af2a576bc1', 50.00, 25.00, 50, 10, true),
  ('ca72cba1-b801-4a25-8254-c8eb63353c0a', 'K00-18', 'Pancit Canton Hot & Spicy', 'Noodles & Pasta', 'a65c4cd0-4828-4ac4-b6fd-10af2a576bc1', 50.00, 25.00, 50, 10, true),
  ('6a1c184d-f98c-4169-9b90-06b0c6ad67b9', 'K00-19', 'Pancit Canton Original', 'Noodles & Pasta', 'a65c4cd0-4828-4ac4-b6fd-10af2a576bc1', 50.00, 25.00, 50, 10, true),
  ('4831bd07-70ff-472c-84a4-c95b7a3c5e6d', 'K00-20', 'Egg', 'Rice & Add-ons', '723f38c2-5cc2-4df5-97f9-18fefa0d2705', 20.00, 10.00, 100, 10, true),
  ('1879a9a2-8fa7-441c-85e8-b2f2853a35d7', 'K00-21', 'White Rice', 'Rice & Add-ons', '723f38c2-5cc2-4df5-97f9-18fefa0d2705', 25.00, 12.50, 98, 10, true),
  ('350c95d2-6b65-4748-a2da-c44312c6281c', 'K00-22', 'Garlic Rice', 'Rice & Add-ons', '723f38c2-5cc2-4df5-97f9-18fefa0d2705', 30.00, 15.00, 100, 10, true),
  ('24a2e369-ce0b-4a8c-ada9-ae17a7ad3f9c', 'K00-23', 'Siomai Pork', 'Snacks & Dimsum', 'c29fd4d3-ee90-4271-ad3d-8f8a41ded74b', 70.00, 35.00, 39, 10, true),
  ('09ce6001-acd0-4209-82c2-6c7da2e7f65d', 'K00-24', 'Siomai Chicken', 'Snacks & Dimsum', 'c29fd4d3-ee90-4271-ad3d-8f8a41ded74b', 70.00, 35.00, 39, 10, true),
  ('c144a422-b7b0-4be7-b296-ff65623dfa5c', 'K00-25', 'Siomai Beef', 'Snacks & Dimsum', 'c29fd4d3-ee90-4271-ad3d-8f8a41ded74b', 75.00, 37.50, 38, 10, true),
  ('5a023b9a-6c7d-4a2f-afc2-d8660eaa252b', 'K00-26', 'Siomai Japanese', 'Snacks & Dimsum', 'c29fd4d3-ee90-4271-ad3d-8f8a41ded74b', 85.00, 42.50, 37, 10, true),
  ('d269168c-00ca-40d1-ba5d-f2ffb82e5008', 'K00-27', 'Siopao', 'Snacks & Dimsum', 'c29fd4d3-ee90-4271-ad3d-8f8a41ded74b', 70.00, 35.00, 24, 10, true),
  ('f6e7f897-a840-4d1a-82f1-705b9070fdef', 'K00-28', 'Spaghetti Longganisa', 'Noodles & Pasta', 'a65c4cd0-4828-4ac4-b6fd-10af2a576bc1', 140.00, 70.00, 25, 10, true),
  ('f64226f3-e931-40a3-a91b-e7f19668341e', 'K00-29', 'Spaghetti Meatballs', 'Noodles & Pasta', 'a65c4cd0-4828-4ac4-b6fd-10af2a576bc1', 150.00, 75.00, 25, 10, true),
  ('890a1a5d-8694-401d-b1f0-65abb3ef4b3b', 'K00-30', 'Pizza', 'Noodles & Pasta', 'a65c4cd0-4828-4ac4-b6fd-10af2a576bc1', 240.00, 120.00, 20, 10, true),
  ('c699465d-dab2-4c80-b7b4-f02925a283d4', 'KW-30', 'Cheese Powder', 'Kitchen Supplies', '3fb61468-d49b-4638-bf99-fcec95841e47', 0.00, 0.00, 10, 10, true),
  ('dc4becb0-ffc4-4e21-a64c-6515a8f3f3b4', 'KW-31', 'BBQ Powder', 'Kitchen Supplies', '3fb61468-d49b-4638-bf99-fcec95841e47', 0.00, 0.00, 10, 10, true),
  ('09103955-d9ce-421c-a932-bf5d224e0def', 'KW-32', 'Sour Cream Powder', 'Kitchen Supplies', '3fb61468-d49b-4638-bf99-fcec95841e47', 0.00, 0.00, 10, 10, true),
  ('70001575-ac70-4c43-ab00-46ecc2535471', 'KW-33', 'Cucumber', 'Kitchen Supplies', '3fb61468-d49b-4638-bf99-fcec95841e47', 0.00, 0.00, 15, 10, true),
  ('76ba413e-b87d-4d72-acd4-4c060e04c064', 'KW-34', 'Tomato', 'Kitchen Supplies', '3fb61468-d49b-4638-bf99-fcec95841e47', 0.00, 0.00, 15, 10, true),
  ('54ef0dc3-f602-4888-922c-095923584c65', 'KW-35', 'Eden Cheese', 'Kitchen Supplies', '3fb61468-d49b-4638-bf99-fcec95841e47', 0.00, 0.00, 12, 10, true),
  ('5f62e485-727c-4fa0-bd35-b6716b0c7ee5', 'KW-36', 'Evap', 'Kitchen Supplies', '3fb61468-d49b-4638-bf99-fcec95841e47', 0.00, 0.00, 20, 10, true)
ON CONFLICT (sku) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  price = EXCLUDED.price,
  cost_price = EXCLUDED.cost_price,
  stock_level = EXCLUDED.stock_level,
  reorder_threshold = EXCLUDED.reorder_threshold,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();
```

---

### 5.3 Dart / Flutter Seed Model & Embedded Static Catalog

Plug this directly into the Flutter POS Register application (`FLUTTER_POS_REPLICATION_PROMPT.md`):

```dart
import 'dart:convert';

class PosProduct {
  final String id;
  final String sku;
  final String name;
  final String category;
  final String department;
  final double price;
  final double costPrice;
  final int stockLevel;
  final int reorderThreshold;
  final bool isActive;

  const PosProduct({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.department,
    required this.price,
    required this.costPrice,
    required this.stockLevel,
    required this.reorderThreshold,
    required this.isActive,
  });

  factory PosProduct.fromJson(Map<String, dynamic> json) {
    return PosProduct(
      id: json['id'] as String,
      sku: json['sku'] as String? ?? 'N/A',
      name: json['name'] as String,
      category: json['category'] as String,
      department: json['department'] as String? ?? 'General',
      price: (json['price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num? ?? 0.0).toDouble(),
      stockLevel: json['stock_level'] as int? ?? 0,
      reorderThreshold: json['reorder_threshold'] as int? ?? 10,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sku': sku,
    'name': name,
    'category': category,
    'department': department,
    'price': price,
    'cost_price': costPrice,
    'stock_level': stockLevel,
    'reorder_threshold': reorderThreshold,
    'is_active': isActive,
  };
}

class PosSeedCatalog {
  static const Map<String, List<String>> departmentCategories = {
    'coffee': ['Coffee', 'Decaf Coffee'],
    'drinks': ['Non-Coffee & Tea', 'Fruit Shakes', 'Beverages & Hydration'],
    'food': ['Silog Meals', 'Snacks & Dimsum', 'Noodles & Pasta', 'Rice & Add-ons'],
    'supplies': ['Bar Supplies', 'Kitchen Supplies'],
  };

  static final List<PosProduct> initialProducts = rawProductsData
      .map((m) => PosProduct.fromJson(m))
      .toList();

  static const List<Map<String, dynamic>> rawProductsData = [
    {
      'id': '6979df8e-3d00-4aa1-9e0e-e5536a1ce6c4',
      'sku': '00-01',
      'name': 'Long Black',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 110.00,
      'cost_price': 55.00,
      'stock_level': 44,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '28d0f9f0-0d86-46a1-83ba-978bdedac326',
      'sku': '00-02',
      'name': 'Capuccino',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 130.00,
      'cost_price': 65.00,
      'stock_level': 49,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '0e86ff8d-70f3-4a9c-ba57-0c5ae41915de',
      'sku': '00-03',
      'name': 'Flat White',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 135.00,
      'cost_price': 67.50,
      'stock_level': 47,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'e972ad24-5be1-4fab-9136-626e6c2b3591',
      'sku': '00-04',
      'name': 'Spanish Latte',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 145.00,
      'cost_price': 72.50,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'b67b6d5d-11cc-470b-9526-dc177a8a4c10',
      'sku': '00-05',
      'name': 'Seasalt Latte',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 150.00,
      'cost_price': 75.00,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '1c73ec74-2cad-4950-a543-d097f9651595',
      'sku': '00-06',
      'name': 'French Vanilla',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 145.00,
      'cost_price': 72.50,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '8a076bfa-e61d-4e8e-a1d0-0b63d5750d1a',
      'sku': '00-07',
      'name': 'Caramel Macchiato',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 150.00,
      'cost_price': 75.00,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '44a0d096-e68b-431a-a2b5-b7c764fa0d17',
      'sku': '00-08',
      'name': 'Salted Caramel',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 145.00,
      'cost_price': 72.50,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '9dc8f952-31a4-47e3-8e7a-c99b1f2bd03e',
      'sku': '00-09',
      'name': 'Brown Sugar Latte',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 145.00,
      'cost_price': 72.50,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '8f9e1a52-59f6-4a00-8d59-ae80825eea57',
      'sku': '00-10',
      'name': 'Mocha Latte',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 150.00,
      'cost_price': 75.00,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '808b0512-e6da-4bc2-9946-40bf6fc271bf',
      'sku': '00-11',
      'name': 'Choco Hazelnut',
      'category': 'Coffee',
      'department': 'Coffee',
      'price': 150.00,
      'cost_price': 75.00,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '65b02d09-0d06-4787-9b71-1aa6093ec9e0',
      'sku': '00-12',
      'name': 'Americano Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 120.00,
      'cost_price': 60.00,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'bd391f2f-4914-4a2a-83d7-3f4638e08294',
      'sku': '00-13',
      'name': 'Flat White Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 145.00,
      'cost_price': 72.50,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'a2b05a74-58b0-4b34-af46-3ca2f8605cc8',
      'sku': '00-14',
      'name': 'Capuccino Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 140.00,
      'cost_price': 70.00,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'ce3982e0-cf51-4c17-b2ab-3e4a776b7750',
      'sku': '00-15',
      'name': 'Spanish Latte Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 155.00,
      'cost_price': 77.50,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '22d879a6-8c1c-4836-a890-082a760cc4a4',
      'sku': '00-16',
      'name': 'French Vanilla Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 155.00,
      'cost_price': 77.50,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '03a0f2b8-018e-4e22-b18d-b70d5db37bc4',
      'sku': '00-17',
      'name': 'Caramel Macchiato Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 160.00,
      'cost_price': 80.00,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'df13732c-2a5c-4dc6-a617-66088a3496a5',
      'sku': '00-18',
      'name': 'Salted Caramel Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 155.00,
      'cost_price': 77.50,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'ff3dc6b9-eab8-4d84-b5de-2d75ca4f24ff',
      'sku': '00-19',
      'name': 'Brown Sugar Latte Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 155.00,
      'cost_price': 77.50,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '0543de7a-83b8-4057-926f-8a7fa5ec3513',
      'sku': '00-20',
      'name': 'Seasalt Butterscotch Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 165.00,
      'cost_price': 82.50,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'a27b17a3-01cf-4183-bb20-579c1bf1c157',
      'sku': '00-21',
      'name': 'Mocha Latte Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 160.00,
      'cost_price': 80.00,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '392f0829-f6c3-4fe7-80a1-d6e606f62679',
      'sku': '00-22',
      'name': 'Choco Hazelnut Decaf',
      'category': 'Decaf Coffee',
      'department': 'Coffee',
      'price': 160.00,
      'cost_price': 80.00,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '2a4683d1-473b-4a45-baf1-54b07e6a13dd',
      'sku': '00-23',
      'name': 'Milk Choco',
      'category': 'Non-Coffee & Tea',
      'department': 'Drinks',
      'price': 120.00,
      'cost_price': 60.00,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '86c430f9-a3ef-43df-90a5-e8f0a2f1276c',
      'sku': '00-24',
      'name': 'Hot Choco',
      'category': 'Non-Coffee & Tea',
      'department': 'Drinks',
      'price': 120.00,
      'cost_price': 60.00,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'a45fd9ee-b217-4233-a26b-4893a08cfdd7',
      'sku': '00-25',
      'name': 'Iced Tea',
      'category': 'Non-Coffee & Tea',
      'department': 'Drinks',
      'price': 65.00,
      'cost_price': 32.50,
      'stock_level': 80,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '89dd9ac6-a789-4bbd-ba15-875d73061bf4',
      'sku': '00-26',
      'name': 'Lychee Aloe',
      'category': 'Non-Coffee & Tea',
      'department': 'Drinks',
      'price': 110.00,
      'cost_price': 55.00,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '8fabaf9f-d7f7-407e-bc6e-4ee9310845ba',
      'sku': '00-27',
      'name': 'Lychee Lemon',
      'category': 'Non-Coffee & Tea',
      'department': 'Drinks',
      'price': 110.00,
      'cost_price': 55.00,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'd7dbf41c-0073-436a-bfa0-e6dd6be43efb',
      'sku': '00-28',
      'name': 'Strawberry Sparkle',
      'category': 'Non-Coffee & Tea',
      'department': 'Drinks',
      'price': 115.00,
      'cost_price': 57.50,
      'stock_level': 40,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '4479c7a1-8e7f-4cbd-ba67-8239765ff000',
      'sku': '00-29',
      'name': 'Banana Shake',
      'category': 'Fruit Shakes',
      'department': 'Drinks',
      'price': 120.00,
      'cost_price': 60.00,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '88890ce1-36c8-4e59-8ce3-7fba3861694b',
      'sku': '00-30',
      'name': 'Mango Shake',
      'category': 'Fruit Shakes',
      'department': 'Drinks',
      'price': 130.00,
      'cost_price': 65.00,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'd8fd6cd9-852f-4387-ba42-12976c69f06d',
      'sku': '00-31',
      'name': 'Strawberry Shake',
      'category': 'Fruit Shakes',
      'department': 'Drinks',
      'price': 130.00,
      'cost_price': 65.00,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'af197263-1185-42ee-84ac-fd5e40c270b3',
      'sku': '00-32',
      'name': 'Water',
      'category': 'Beverages & Hydration',
      'department': 'Drinks',
      'price': 30.00,
      'cost_price': 15.00,
      'stock_level': 150,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'd2f08090-f2bd-4380-b13f-0a2dfc9e6ba2',
      'sku': '00-33',
      'name': 'Coke',
      'category': 'Beverages & Hydration',
      'department': 'Drinks',
      'price': 55.00,
      'cost_price': 27.50,
      'stock_level': 59,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '8f7d0acc-25d0-4c36-a19f-7c15e08a58fc',
      'sku': '00-34',
      'name': 'Royal',
      'category': 'Beverages & Hydration',
      'department': 'Drinks',
      'price': 55.00,
      'cost_price': 27.50,
      'stock_level': 60,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'd05c8e98-326e-451f-9429-6aea06a09571',
      'sku': '00-35',
      'name': 'Sprite',
      'category': 'Beverages & Hydration',
      'department': 'Drinks',
      'price': 55.00,
      'cost_price': 27.50,
      'stock_level': 60,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'da9e547d-f016-4f34-8ca2-45b69a4beb24',
      'sku': '00-36',
      'name': 'Coke Zero',
      'category': 'Beverages & Hydration',
      'department': 'Drinks',
      'price': 55.00,
      'cost_price': 27.50,
      'stock_level': 60,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '189283f8-b5ad-4daf-8ddd-134aa23b838e',
      'sku': '00-37',
      'name': 'Gatorade Blue',
      'category': 'Beverages & Hydration',
      'department': 'Drinks',
      'price': 75.00,
      'cost_price': 37.50,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'a24d6ab3-e81d-4a29-b065-c271f82170c5',
      'sku': '00-38',
      'name': 'Gatorade Violet',
      'category': 'Beverages & Hydration',
      'department': 'Drinks',
      'price': 75.00,
      'cost_price': 37.50,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '04a2064b-2b5f-4537-bb91-3710b9777dee',
      'sku': '00-39',
      'name': 'Gatorade Red',
      'category': 'Beverages & Hydration',
      'department': 'Drinks',
      'price': 75.00,
      'cost_price': 37.50,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '210c3c2e-ac71-4cee-a7b9-cec965a95446',
      'sku': '00-40',
      'name': 'Pocari',
      'category': 'Beverages & Hydration',
      'department': 'Drinks',
      'price': 70.00,
      'cost_price': 35.00,
      'stock_level': 60,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '60df43f9-b8c2-4658-8332-47e3d5866e9e',
      'sku': 'BW-41',
      'name': 'Vivo',
      'category': 'Bar Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 10,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'c33fd977-57f9-4636-9f3a-dd49f60a1f73',
      'sku': 'BW-42',
      'name': 'Fresh Milk',
      'category': 'Bar Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 21,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'ee8fbad4-8e40-4fed-83e8-6dda08bfa04f',
      'sku': 'BW-43',
      'name': 'Oatside',
      'category': 'Bar Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 15,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'ba78a6fc-8ceb-42ff-b429-e2fcc307c267',
      'sku': 'BW-44',
      'name': 'Vanilla Syrup',
      'category': 'Bar Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 5,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'd180810b-62c1-4809-9f1c-61ef2f009c06',
      'sku': 'BW-45',
      'name': 'Hazelnut Syrup',
      'category': 'Bar Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 6,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'c13cd4d9-477e-4098-b642-1d690887d51d',
      'sku': 'BW-46',
      'name': 'French Vanilla Syrup',
      'category': 'Bar Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 6,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '68252bdc-6339-46e0-b996-b6bbf8a8205a',
      'sku': 'BW-47',
      'name': 'Caramel Syrup',
      'category': 'Bar Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 6,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'c46acdc6-cf99-422e-af63-8f1af3673e08',
      'sku': 'BW-48',
      'name': 'Chocolate Syrup',
      'category': 'Bar Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 5,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '48022483-3229-4df2-bde3-fd0331892b85',
      'sku': 'BW-49',
      'name': 'Lychee',
      'category': 'Bar Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 10,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '30e3cc60-64b6-4a3a-b5e9-ae4513980def',
      'sku': 'BW-50',
      'name': 'Condensed',
      'category': 'Bar Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 24,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'fd16fb52-910d-4a37-b9a0-92f956d596aa',
      'sku': 'K00-01',
      'name': 'Baconsilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 140.00,
      'cost_price': 70.00,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '4903241b-358d-4f72-9f3a-7e57dce14cef',
      'sku': 'K00-02',
      'name': 'Bangsilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 155.00,
      'cost_price': 77.50,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'acde9161-2a05-4c3a-b0c7-67797339d13a',
      'sku': 'K00-03',
      'name': 'Chickensilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 150.00,
      'cost_price': 75.00,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '82ad034b-919a-4934-891e-1301b7221787',
      'sku': 'K00-04',
      'name': 'Cornsilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 130.00,
      'cost_price': 65.00,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '973f9ab4-bc52-4476-9d0d-5b658746d734',
      'sku': 'K00-05',
      'name': 'Hotsilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 120.00,
      'cost_price': 60.00,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '28b0281e-313c-469a-a059-dac398ff018d',
      'sku': 'K00-06',
      'name': 'Liemposilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 165.00,
      'cost_price': 82.50,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'a4fbb946-e566-4150-9f8f-5acf2768e215',
      'sku': 'K00-07',
      'name': 'Garlic Longsilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 140.00,
      'cost_price': 70.00,
      'stock_level': 29,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '7ebd1d03-0b1e-4e84-9d1c-9664ddb1841e',
      'sku': 'K00-08',
      'name': 'Sweet Longsilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 140.00,
      'cost_price': 70.00,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '4c0d21f7-6b3c-4a7a-9c2d-6c3df5cfc1fc',
      'sku': 'K00-09',
      'name': 'Tapsilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 160.00,
      'cost_price': 80.00,
      'stock_level': 31,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '8b929727-6483-41cb-9f6d-63b2e88b90dc',
      'sku': 'K00-10',
      'name': 'Tocilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 145.00,
      'cost_price': 72.50,
      'stock_level': 27,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '6da38a3d-9baa-4453-9121-d0a6132915a8',
      'sku': 'K00-11',
      'name': 'Spamsilog',
      'category': 'Silog Meals',
      'department': 'Food',
      'price': 145.00,
      'cost_price': 72.50,
      'stock_level': 30,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '53a0e2d1-7368-46d1-bb26-7f758d7554fd',
      'sku': 'K00-12',
      'name': 'Beef Nachos',
      'category': 'Snacks & Dimsum',
      'department': 'Food',
      'price': 150.00,
      'cost_price': 75.00,
      'stock_level': 23,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '6d69cd0c-7ff8-4efc-b3ee-bb1ae80642e1',
      'sku': 'K00-13',
      'name': 'Toge',
      'category': 'Snacks & Dimsum',
      'department': 'Food',
      'price': 65.00,
      'cost_price': 32.50,
      'stock_level': 27,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'b7a11614-a94f-4e97-8a70-60bafcdadeaf',
      'sku': 'K00-14',
      'name': 'Fries',
      'category': 'Snacks & Dimsum',
      'department': 'Food',
      'price': 90.00,
      'cost_price': 45.00,
      'stock_level': 38,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '07a5d27d-4695-4c06-81c2-c958eb62e097',
      'sku': 'K00-15',
      'name': 'Pancit Canton Sweet & Spicy',
      'category': 'Noodles & Pasta',
      'department': 'Food',
      'price': 50.00,
      'cost_price': 25.00,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'f6dacb8d-8bf0-4870-9165-eaf0643d7195',
      'sku': 'K00-16',
      'name': 'Pancit Canton Chilimansi',
      'category': 'Noodles & Pasta',
      'department': 'Food',
      'price': 50.00,
      'cost_price': 25.00,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '095ea22a-a66b-4927-8609-5d7065b79018',
      'sku': 'K00-17',
      'name': 'Pancit Canton Calamansi',
      'category': 'Noodles & Pasta',
      'department': 'Food',
      'price': 50.00,
      'cost_price': 25.00,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'ca72cba1-b801-4a25-8254-c8eb63353c0a',
      'sku': 'K00-18',
      'name': 'Pancit Canton Hot & Spicy',
      'category': 'Noodles & Pasta',
      'department': 'Food',
      'price': 50.00,
      'cost_price': 25.00,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '6a1c184d-f98c-4169-9b90-06b0c6ad67b9',
      'sku': 'K00-19',
      'name': 'Pancit Canton Original',
      'category': 'Noodles & Pasta',
      'department': 'Food',
      'price': 50.00,
      'cost_price': 25.00,
      'stock_level': 50,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '4831bd07-70ff-472c-84a4-c95b7a3c5e6d',
      'sku': 'K00-20',
      'name': 'Egg',
      'category': 'Rice & Add-ons',
      'department': 'Food',
      'price': 20.00,
      'cost_price': 10.00,
      'stock_level': 100,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '1879a9a2-8fa7-441c-85e8-b2f2853a35d7',
      'sku': 'K00-21',
      'name': 'White Rice',
      'category': 'Rice & Add-ons',
      'department': 'Food',
      'price': 25.00,
      'cost_price': 12.50,
      'stock_level': 98,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '350c95d2-6b65-4748-a2da-c44312c6281c',
      'sku': 'K00-22',
      'name': 'Garlic Rice',
      'category': 'Rice & Add-ons',
      'department': 'Food',
      'price': 30.00,
      'cost_price': 15.00,
      'stock_level': 100,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '24a2e369-ce0b-4a8c-ada9-ae17a7ad3f9c',
      'sku': 'K00-23',
      'name': 'Siomai Pork',
      'category': 'Snacks & Dimsum',
      'department': 'Food',
      'price': 70.00,
      'cost_price': 35.00,
      'stock_level': 39,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '09ce6001-acd0-4209-82c2-6c7da2e7f65d',
      'sku': 'K00-24',
      'name': 'Siomai Chicken',
      'category': 'Snacks & Dimsum',
      'department': 'Food',
      'price': 70.00,
      'cost_price': 35.00,
      'stock_level': 39,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'c144a422-b7b0-4be7-b296-ff65623dfa5c',
      'sku': 'K00-25',
      'name': 'Siomai Beef',
      'category': 'Snacks & Dimsum',
      'department': 'Food',
      'price': 75.00,
      'cost_price': 37.50,
      'stock_level': 38,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '5a023b9a-6c7d-4a2f-afc2-d8660eaa252b',
      'sku': 'K00-26',
      'name': 'Siomai Japanese',
      'category': 'Snacks & Dimsum',
      'department': 'Food',
      'price': 85.00,
      'cost_price': 42.50,
      'stock_level': 37,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'd269168c-00ca-40d1-ba5d-f2ffb82e5008',
      'sku': 'K00-27',
      'name': 'Siopao',
      'category': 'Snacks & Dimsum',
      'department': 'Food',
      'price': 70.00,
      'cost_price': 35.00,
      'stock_level': 24,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'f6e7f897-a840-4d1a-82f1-705b9070fdef',
      'sku': 'K00-28',
      'name': 'Spaghetti Longganisa',
      'category': 'Noodles & Pasta',
      'department': 'Food',
      'price': 140.00,
      'cost_price': 70.00,
      'stock_level': 25,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'f64226f3-e931-40a3-a91b-e7f19668341e',
      'sku': 'K00-29',
      'name': 'Spaghetti Meatballs',
      'category': 'Noodles & Pasta',
      'department': 'Food',
      'price': 150.00,
      'cost_price': 75.00,
      'stock_level': 25,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '890a1a5d-8694-401d-b1f0-65abb3ef4b3b',
      'sku': 'K00-30',
      'name': 'Pizza',
      'category': 'Noodles & Pasta',
      'department': 'Food',
      'price': 240.00,
      'cost_price': 120.00,
      'stock_level': 20,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'c699465d-dab2-4c80-b7b4-f02925a283d4',
      'sku': 'KW-30',
      'name': 'Cheese Powder',
      'category': 'Kitchen Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 10,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': 'dc4becb0-ffc4-4e21-a64c-6515a8f3f3b4',
      'sku': 'KW-31',
      'name': 'BBQ Powder',
      'category': 'Kitchen Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 10,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '09103955-d9ce-421c-a932-bf5d224e0def',
      'sku': 'KW-32',
      'name': 'Sour Cream Powder',
      'category': 'Kitchen Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 10,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '70001575-ac70-4c43-ab00-46ecc2535471',
      'sku': 'KW-33',
      'name': 'Cucumber',
      'category': 'Kitchen Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 15,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '76ba413e-b87d-4d72-acd4-4c060e04c064',
      'sku': 'KW-34',
      'name': 'Tomato',
      'category': 'Kitchen Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 15,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '54ef0dc3-f602-4888-922c-095923584c65',
      'sku': 'KW-35',
      'name': 'Eden Cheese',
      'category': 'Kitchen Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 12,
      'reorder_threshold': 10,
      'is_active': true,
    },
    {
      'id': '5f62e485-727c-4fa0-bd35-b6716b0c7ee5',
      'sku': 'KW-36',
      'name': 'Evap',
      'category': 'Kitchen Supplies',
      'department': 'Supplies',
      'price': 0.00,
      'cost_price': 0.00,
      'stock_level': 20,
      'reorder_threshold': 10,
      'is_active': true,
    },
  ];
}
```

---

### 5.4 CSV Tabular Export

```csv
sku,name,category,department,price,cost_price,stock_level,reorder_threshold,is_active,id
00-01,Long Black,Coffee,Coffee,110.00,55.00,44,10,true,6979df8e-3d00-4aa1-9e0e-e5536a1ce6c4
00-02,Capuccino,Coffee,Coffee,130.00,65.00,49,10,true,28d0f9f0-0d86-46a1-83ba-978bdedac326
00-03,Flat White,Coffee,Coffee,135.00,67.50,47,10,true,0e86ff8d-70f3-4a9c-ba57-0c5ae41915de
00-04,Spanish Latte,Coffee,Coffee,145.00,72.50,50,10,true,e972ad24-5be1-4fab-9136-626e6c2b3591
00-05,Seasalt Latte,Coffee,Coffee,150.00,75.00,50,10,true,b67b6d5d-11cc-470b-9526-dc177a8a4c10
00-06,French Vanilla,Coffee,Coffee,145.00,72.50,50,10,true,1c73ec74-2cad-4950-a543-d097f9651595
00-07,Caramel Macchiato,Coffee,Coffee,150.00,75.00,50,10,true,8a076bfa-e61d-4e8e-a1d0-0b63d5750d1a
00-08,Salted Caramel,Coffee,Coffee,145.00,72.50,50,10,true,44a0d096-e68b-431a-a2b5-b7c764fa0d17
00-09,Brown Sugar Latte,Coffee,Coffee,145.00,72.50,50,10,true,9dc8f952-31a4-47e3-8e7a-c99b1f2bd03e
00-10,Mocha Latte,Coffee,Coffee,150.00,75.00,50,10,true,8f9e1a52-59f6-4a00-8d59-ae80825eea57
00-11,Choco Hazelnut,Coffee,Coffee,150.00,75.00,50,10,true,808b0512-e6da-4bc2-9946-40bf6fc271bf
00-12,Americano Decaf,Decaf Coffee,Coffee,120.00,60.00,40,10,true,65b02d09-0d06-4787-9b71-1aa6093ec9e0
00-13,Flat White Decaf,Decaf Coffee,Coffee,145.00,72.50,40,10,true,bd391f2f-4914-4a2a-83d7-3f4638e08294
00-14,Capuccino Decaf,Decaf Coffee,Coffee,140.00,70.00,40,10,true,a2b05a74-58b0-4b34-af46-3ca2f8605cc8
00-15,Spanish Latte Decaf,Decaf Coffee,Coffee,155.00,77.50,40,10,true,ce3982e0-cf51-4c17-b2ab-3e4a776b7750
00-16,French Vanilla Decaf,Decaf Coffee,Coffee,155.00,77.50,40,10,true,22d879a6-8c1c-4836-a890-082a760cc4a4
00-17,Caramel Macchiato Decaf,Decaf Coffee,Coffee,160.00,80.00,40,10,true,03a0f2b8-018e-4e22-b18d-b70d5db37bc4
00-18,Salted Caramel Decaf,Decaf Coffee,Coffee,155.00,77.50,40,10,true,df13732c-2a5c-4dc6-a617-66088a3496a5
00-19,Brown Sugar Latte Decaf,Decaf Coffee,Coffee,155.00,77.50,40,10,true,ff3dc6b9-eab8-4d84-b5de-2d75ca4f24ff
00-20,Seasalt Butterscotch Decaf,Decaf Coffee,Coffee,165.00,82.50,40,10,true,0543de7a-83b8-4057-926f-8a7fa5ec3513
00-21,Mocha Latte Decaf,Decaf Coffee,Coffee,160.00,80.00,40,10,true,a27b17a3-01cf-4183-bb20-579c1bf1c157
00-22,Choco Hazelnut Decaf,Decaf Coffee,Coffee,160.00,80.00,40,10,true,392f0829-f6c3-4fe7-80a1-d6e606f62679
00-23,Milk Choco,Non-Coffee & Tea,Drinks,120.00,60.00,40,10,true,2a4683d1-473b-4a45-baf1-54b07e6a13dd
00-24,Hot Choco,Non-Coffee & Tea,Drinks,120.00,60.00,40,10,true,86c430f9-a3ef-43df-90a5-e8f0a2f1276c
00-25,Iced Tea,Non-Coffee & Tea,Drinks,65.00,32.50,80,10,true,a45fd9ee-b217-4233-a26b-4893a08cfdd7
00-26,Lychee Aloe,Non-Coffee & Tea,Drinks,110.00,55.00,40,10,true,89dd9ac6-a789-4bbd-ba15-875d73061bf4
00-27,Lychee Lemon,Non-Coffee & Tea,Drinks,110.00,55.00,40,10,true,8fabaf9f-d7f7-407e-bc6e-4ee9310845ba
00-28,Strawberry Sparkle,Non-Coffee & Tea,Drinks,115.00,57.50,40,10,true,d7dbf41c-0073-436a-bfa0-e6dd6be43efb
00-29,Banana Shake,Fruit Shakes,Drinks,120.00,60.00,30,10,true,4479c7a1-8e7f-4cbd-ba67-8239765ff000
00-30,Mango Shake,Fruit Shakes,Drinks,130.00,65.00,30,10,true,88890ce1-36c8-4e59-8ce3-7fba3861694b
00-31,Strawberry Shake,Fruit Shakes,Drinks,130.00,65.00,30,10,true,d8fd6cd9-852f-4387-ba42-12976c69f06d
00-32,Water,Beverages & Hydration,Drinks,30.00,15.00,150,10,true,af197263-1185-42ee-84ac-fd5e40c270b3
00-33,Coke,Beverages & Hydration,Drinks,55.00,27.50,59,10,true,d2f08090-f2bd-4380-b13f-0a2dfc9e6ba2
00-34,Royal,Beverages & Hydration,Drinks,55.00,27.50,60,10,true,8f7d0acc-25d0-4c36-a19f-7c15e08a58fc
00-35,Sprite,Beverages & Hydration,Drinks,55.00,27.50,60,10,true,d05c8e98-326e-451f-9429-6aea06a09571
00-36,Coke Zero,Beverages & Hydration,Drinks,55.00,27.50,60,10,true,da9e547d-f016-4f34-8ca2-45b69a4beb24
00-37,Gatorade Blue,Beverages & Hydration,Drinks,75.00,37.50,50,10,true,189283f8-b5ad-4daf-8ddd-134aa23b838e
00-38,Gatorade Violet,Beverages & Hydration,Drinks,75.00,37.50,50,10,true,a24d6ab3-e81d-4a29-b065-c271f82170c5
00-39,Gatorade Red,Beverages & Hydration,Drinks,75.00,37.50,50,10,true,04a2064b-2b5f-4537-bb91-3710b9777dee
00-40,Pocari,Beverages & Hydration,Drinks,70.00,35.00,60,10,true,210c3c2e-ac71-4cee-a7b9-cec965a95446
BW-41,Vivo,Bar Supplies,Supplies,0.00,0.00,10,10,true,60df43f9-b8c2-4658-8332-47e3d5866e9e
BW-42,Fresh Milk,Bar Supplies,Supplies,0.00,0.00,21,10,true,c33fd977-57f9-4636-9f3a-dd49f60a1f73
BW-43,Oatside,Bar Supplies,Supplies,0.00,0.00,15,10,true,ee8fbad4-8e40-4fed-83e8-6dda08bfa04f
BW-44,Vanilla Syrup,Bar Supplies,Supplies,0.00,0.00,5,10,true,ba78a6fc-8ceb-42ff-b429-e2fcc307c267
BW-45,Hazelnut Syrup,Bar Supplies,Supplies,0.00,0.00,6,10,true,d180810b-62c1-4809-9f1c-61ef2f009c06
BW-46,French Vanilla Syrup,Bar Supplies,Supplies,0.00,0.00,6,10,true,c13cd4d9-477e-4098-b642-1d690887d51d
BW-47,Caramel Syrup,Bar Supplies,Supplies,0.00,0.00,6,10,true,68252bdc-6339-46e0-b996-b6bbf8a8205a
BW-48,Chocolate Syrup,Bar Supplies,Supplies,0.00,0.00,5,10,true,c46acdc6-cf99-422e-af63-8f1af3673e08
BW-49,Lychee,Bar Supplies,Supplies,0.00,0.00,10,10,true,48022483-3229-4df2-bde3-fd0331892b85
BW-50,Condensed,Bar Supplies,Supplies,0.00,0.00,24,10,true,30e3cc60-64b6-4a3a-b5e9-ae4513980def
K00-01,Baconsilog,Silog Meals,Food,140.00,70.00,30,10,true,fd16fb52-910d-4a37-b9a0-92f956d596aa
K00-02,Bangsilog,Silog Meals,Food,155.00,77.50,30,10,true,4903241b-358d-4f72-9f3a-7e57dce14cef
K00-03,Chickensilog,Silog Meals,Food,150.00,75.00,30,10,true,acde9161-2a05-4c3a-b0c7-67797339d13a
K00-04,Cornsilog,Silog Meals,Food,130.00,65.00,30,10,true,82ad034b-919a-4934-891e-1301b7221787
K00-05,Hotsilog,Silog Meals,Food,120.00,60.00,30,10,true,973f9ab4-bc52-4476-9d0d-5b658746d734
K00-06,Liemposilog,Silog Meals,Food,165.00,82.50,30,10,true,28b0281e-313c-469a-a059-dac398ff018d
K00-07,Garlic Longsilog,Silog Meals,Food,140.00,70.00,29,10,true,a4fbb946-e566-4150-9f8f-5acf2768e215
K00-08,Sweet Longsilog,Silog Meals,Food,140.00,70.00,30,10,true,7ebd1d03-0b1e-4e84-9d1c-9664ddb1841e
K00-09,Tapsilog,Silog Meals,Food,160.00,80.00,31,10,true,4c0d21f7-6b3c-4a7a-9c2d-6c3df5cfc1fc
K00-10,Tocilog,Silog Meals,Food,145.00,72.50,27,10,true,8b929727-6483-41cb-9f6d-63b2e88b90dc
K00-11,Spamsilog,Silog Meals,Food,145.00,72.50,30,10,true,6da38a3d-9baa-4453-9121-d0a6132915a8
K00-12,Beef Nachos,Snacks & Dimsum,Food,150.00,75.00,23,10,true,53a0e2d1-7368-46d1-bb26-7f758d7554fd
K00-13,Toge,Snacks & Dimsum,Food,65.00,32.50,27,10,true,6d69cd0c-7ff8-4efc-b3ee-bb1ae80642e1
K00-14,Fries,Snacks & Dimsum,Food,90.00,45.00,38,10,true,b7a11614-a94f-4e97-8a70-60bafcdadeaf
K00-15,Pancit Canton Sweet & Spicy,Noodles & Pasta,Food,50.00,25.00,50,10,true,07a5d27d-4695-4c06-81c2-c958eb62e097
K00-16,Pancit Canton Chilimansi,Noodles & Pasta,Food,50.00,25.00,50,10,true,f6dacb8d-8bf0-4870-9165-eaf0643d7195
K00-17,Pancit Canton Calamansi,Noodles & Pasta,Food,50.00,25.00,50,10,true,095ea22a-a66b-4927-8609-5d7065b79018
K00-18,Pancit Canton Hot & Spicy,Noodles & Pasta,Food,50.00,25.00,50,10,true,ca72cba1-b801-4a25-8254-c8eb63353c0a
K00-19,Pancit Canton Original,Noodles & Pasta,Food,50.00,25.00,50,10,true,6a1c184d-f98c-4169-9b90-06b0c6ad67b9
K00-20,Egg,Rice & Add-ons,Food,20.00,10.00,100,10,true,4831bd07-70ff-472c-84a4-c95b7a3c5e6d
K00-21,White Rice,Rice & Add-ons,Food,25.00,12.50,98,10,true,1879a9a2-8fa7-441c-85e8-b2f2853a35d7
K00-22,Garlic Rice,Rice & Add-ons,Food,30.00,15.00,100,10,true,350c95d2-6b65-4748-a2da-c44312c6281c
K00-23,Siomai Pork,Snacks & Dimsum,Food,70.00,35.00,39,10,true,24a2e369-ce0b-4a8c-ada9-ae17a7ad3f9c
K00-24,Siomai Chicken,Snacks & Dimsum,Food,70.00,35.00,39,10,true,09ce6001-acd0-4209-82c2-6c7da2e7f65d
K00-25,Siomai Beef,Snacks & Dimsum,Food,75.00,37.50,38,10,true,c144a422-b7b0-4be7-b296-ff65623dfa5c
K00-26,Siomai Japanese,Snacks & Dimsum,Food,85.00,42.50,37,10,true,5a023b9a-6c7d-4a2f-afc2-d8660eaa252b
K00-27,Siopao,Snacks & Dimsum,Food,70.00,35.00,24,10,true,d269168c-00ca-40d1-ba5d-f2ffb82e5008
K00-28,Spaghetti Longganisa,Noodles & Pasta,Food,140.00,70.00,25,10,true,f6e7f897-a840-4d1a-82f1-705b9070fdef
K00-29,Spaghetti Meatballs,Noodles & Pasta,Food,150.00,75.00,25,10,true,f64226f3-e931-40a3-a91b-e7f19668341e
K00-30,Pizza,Noodles & Pasta,Food,240.00,120.00,20,10,true,890a1a5d-8694-401d-b1f0-65abb3ef4b3b
KW-30,Cheese Powder,Kitchen Supplies,Supplies,0.00,0.00,10,10,true,c699465d-dab2-4c80-b7b4-f02925a283d4
KW-31,BBQ Powder,Kitchen Supplies,Supplies,0.00,0.00,10,10,true,dc4becb0-ffc4-4e21-a64c-6515a8f3f3b4
KW-32,Sour Cream Powder,Kitchen Supplies,Supplies,0.00,0.00,10,10,true,09103955-d9ce-421c-a932-bf5d224e0def
KW-33,Cucumber,Kitchen Supplies,Supplies,0.00,0.00,15,10,true,70001575-ac70-4c43-ab00-46ecc2535471
KW-34,Tomato,Kitchen Supplies,Supplies,0.00,0.00,15,10,true,76ba413e-b87d-4d72-acd4-4c060e04c064
KW-35,Eden Cheese,Kitchen Supplies,Supplies,0.00,0.00,12,10,true,54ef0dc3-f602-4888-922c-095923584c65
KW-36,Evap,Kitchen Supplies,Supplies,0.00,0.00,20,10,true,5f62e485-727c-4fa0-bd35-b6716b0c7ee5
```
