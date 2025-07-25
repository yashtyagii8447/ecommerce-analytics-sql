# 🛒 E-Commerce User Behavior Analysis (SQL Star Schema Project)

## 📌 Project Objective

The goal of this project is to analyze raw clickstream data from an e-commerce platform and transform it into a clean, queryable star schema. We derive business insights by creating dimension and fact tables, followed by a series of analytical SQL queries that answer user behavior, product performance, and revenue trend questions.

---
## 📁 Dataset

This project uses the [Ecommerce Behavior Data from Multi Category Store](https://www.kaggle.com/datasets/mkechinov/ecommerce-behavior-data-from-multi-category-store/data) available on Kaggle.

Due to GitHub’s file size limitations, the dataset is not stored in this repository.

You can download it from the link below:

🔗 **[Download the Dataset on Kaggle](https://www.kaggle.com/datasets/mkechinov/ecommerce-behavior-data-from-multi-category-store/data)**


---

## 🧱 Star Schema Design

### 🧩 Fact Table

- **fact_sales**: Central table containing user events such as view, cart, purchase, and return. Each row represents an event tied to a product, time, user, and session.

### 🧩 Dimension Tables

- **dim_date**: Extracted from event timestamps to support time-based aggregations (year, month, day, etc.).
- **dim_products**: Maps product_id to product_key, brand, and category_id.
- **dim_category**: Maps category_id to a readable category_code (hierarchical product categorization).
- **dim_users**: Captures distinct user-level data from raw logs.
- **dim_sessions**: Captures unique session information used for behavioral analysis.

---

## 📦 Data Cleaning & Transformation

1. **Raw Table**: `raw_events` loaded directly from source CSV (includes `event_type`, `event_time`, `product_id`, `brand`, `user_id`, `price`, etc.).
2. **Cleaned Table**: `clean_events` ensures proper data types, removes NULLs, deduplicates, and filters invalid events.
3. **Normalization**: Breaks large table into modular tables (dim + fact), optimizing for joins and clarity.

---

## 💡 Key Business Questions Answered

### ✅ General User Insights

- **Q1**: Total unique users?
- **Q2**: Number of sessions per user?
- **Q3**: Users who only viewed but never purchased?
- **Q4**: Average order value per user?

---

### 📦 Product & Brand Performance

- **Q5**: Which category generated the highest total revenue?
- **Q6**: Top 5 brands by number of purchases?
- **Q7**: Product with highest average selling price (min 5 sales)?

---

### 📈 Time Series Trends

- **Q8**: Monthly total revenue trend
- **Q9**: Month with the highest number of purchases
- **Q10**: Daily average revenue in each month
- **Q11**: Top 3 users by total spend
- **Q12**: Monthly purchase count & revenue

---

### 🔁 Behavioral Analysis

- **Q13**: Repeat purchase rate
- **Q14**: % of users who made more than one purchase
- **Q15**: Average days between purchases per user
- **Q16**: Top 3 most returned product categories
- **Q17**: First vs most recent purchase date for each user
- **Q18**: Conversion rate (views → purchases)
- **Q19**: Return rate (% of purchases returned)
- **Q20**: Monthly return rate trend
- **Q21**: Users who purchased and later returned the same product

---

### 💎 Bonus Insights

#### 🔸 B. High-Value Customer Segmentation
- **B1**: Users with highest average order value (AOV)
- **B2**: Users with low return rate but high revenue

#### 🔸 C. Funnel Analysis
- Conversion drop-off: **View → Cart → Purchase**
- Also includes direct **View → Purchase** funnel

---

## 📊 Suggested Dashboard:
#  Visualization of the following can be using tools like Tableau / Power BI.

- **KPI Cards**:
  - Total Revenue
  - Conversion Rate
  - Return Rate
  - Average Order Value
  - Top Brand & Category

- **Line Charts**:
  - Monthly revenue trends
  - Monthly purchase vs return rates

- **Bar Charts**:
  - Top 5 Users by Spend
  - Most Popular Brands
  - Most Returned Categories

- **Funnel Chart**:
  - View → Cart → Purchase drop-off

- **Heatmaps**:
  - Purchase Frequency by Day of Week or Month

---

## 🛠 Tools Used

- **SQL (MySQL Workbench)**: Data transformation, modeling, and querying
- **Spreadsheet/CSV**: Initial raw data input

---

## ✅ Summary

This project demonstrates how raw log data can be transformed into an analytical star schema, and used to answer 20+ real-world business questions across user behavior, revenue generation, and product performance. This project showcases end-to-end SQL modeling and analysis.
