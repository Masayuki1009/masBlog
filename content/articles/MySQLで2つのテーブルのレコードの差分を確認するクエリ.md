---
title: MySQLで2つのテーブルのレコードの差分を確認するクエリ
date: 2025-05-21
type: articles
---
# 本記事はこんな人にオススメ
テーブルの差分取得できん人
差分取れるけどどこで発生してんのか見づらいわ！と感じでいる人
他のDBでは差分抽出のやり方わかるけどMySQLでどうやんの？って人

# 経緯
業務でMySQLのテーブル間の差分を抽出する作業があった際の取り組みをまとめる。

# 概要
MySQLにおける2つのテーブルのレコードの差分を抽出するクエリをまとめる。
実際に例としてテーブルを用意し、どのようにデータが取得されるのかを記載する。
ただ差分を取得するだけでなく、どこでどのような差分が発生しているかまでフォーカスする。

# 検証
今回は、実際に以下のuser_example1テーブルとuser_example2テーブルを作成し実際の出力内容の方を確認していく。
user_example1テーブル

| id  | username  | email                 | password     |
| --- | --------- | --------------------- | ------------ |
| 1   | Sato      | sato@example.com      | sato123      |
| 2   | Suzuki    | suzuki@example.com    | suzuki123    |
| 3   | Takahashi | takahashi@example.com | takahashi123 |
| 4   | Tanaka    | tanaka@example.com    | tanaka123    |
| 5   | Ito       | ito@example.com       | ito123       |
user_example2テーブル

| id  | username  | email                 | password     |
| --- | --------- | --------------------- | ------------ |
| 1   | Sato      | sato@example.com      | sato123      |
| 2   | Suzuki    | suzuki@example.com    | suzuki123    |
| 3   | Takahashi | takahashi@example.com | takahashi123 |
| 4   | Takahashi | tanaka@example.com    | tanaka123    |
| 5   | NULL      | ito@example.com       | ito123       |

差分：
id=4のusernameが異なる
id=5のusernameがNULLになっている

### 1. MySQL 8.0.31以降の場合
EXCEPT演算子を使用することで差分を簡単に取得できる
```sql
SELECT * FROM user_example1
EXCEPT 
SELECT * FROM user_example2;
```
実行結果(MySQL WorkBench)
![スクリーンショット 2025-05-21 20.23.26.png](/images/スクリーンショット%202025-05-21%2020.23.26.png)
*メリット*
・クエリが短い＋作成が簡単
*デメリット*
・MySQL version8.0.31以降しか使用できない
・差分がどこでどのように発生しているか分かりづらい
EXCEPTは重複行を削除するため、具体的なテーブル間の差分が実行結果から一目では読み取れない
上記の場合実行結果としてuser_example1テーブルのレコードが取得されているが、以下のようにテーブル名を入れ替えてクエリを実行すると
```sql
SELECT * FROM user_example2
EXCEPT 
SELECT * FROM user_example1;
```
実行結果(MySQL WorkBench)
![スクリーンショット 2025-05-21 21.49.34.png](/images/スクリーンショット%202025-05-21%2021.49.34.png)
user_example2からのみレコードが取得されてしまうという特性がある
参考：https://dev.mysql.com/doc/refman/8.4/en/except.html


### 2. MySQL 8.0.31以前の場合
#### 2.1 INNER JOIN + WHERE NOTで細かく差分を特定
```sql
SELECT 
	t1.id,
	t1.username AS t1_username,
	t2.username AS t2_username,
	t1.email AS t1_email,
	t2.email AS t2_email,
	t1.password AS t1_password,
	t2.password AS t2_password
FROM user_example1 t1 
INNER JOIN user_example2 t2 
ON t1.id = t2.id 
WHERE NOT (
t1.username <=> t2.username AND
t1.email <=> t2.email AND
t1.password <=> t2.password
);
```
実行結果(MySQL WorkBench)
![スクリーンショット 2025-05-21 20.26.32.png](/images/スクリーンショット%202025-05-21%2020.26.32.png)
*メリット*
・MySQLバージョンを問わない
・カラムが隣り合わせで取得されるので、どのカラムでどのような差分が発生しているかが分かりやすい
・nullチェック可能
`<=>`（NULL-safe equal）は SQL の `IS NOT DISTINCT FROM` 相当で、両オペランドが NULL の場合は TRUE を返す→差分なしと扱われる
*デメリット*
・クエリ作成が面倒
・この方式は「id が両方に存在する」行だけを比べるので、**片方にしか存在しない id（行追加／削除）は検知できない**
・大規模テーブルでフルスキャンの場合パフォーマンスの問題が発生する可能性があるため、差分抽出用に `PRIMARY KEY` や比較対象列のインデックスを貼るなどの対策が必要な場合あり



#### 2.2 2.1の簡略版
```sql
SELECT 
	t1.*,
	t2.*
FROM user_example1 t1 
INNER JOIN user_example2 t2 
ON t1.id = t2.id 
WHERE NOT (
t1.username <=> t2.username AND
t1.email <=> t2.email AND
t1.password <=> t2.password
);
```
実行結果(MySQL WorkBench)
![スクリーンショット 2025-05-21 20.24.43.png](/images/スクリーンショット%202025-05-21%2020.24.43.png)
*メリット*
・クエリ作成が2.1よりは簡単
・小規模テーブルの場合はこれで充分な場合が多い
*デメリット*
・取得結果がt1のレコード→t2のレコードの順に横並びになるので、テーブル規模が大きいと一目で差分の発生箇所が確認しづらい



#### 2.3 UNION ALL ＋ GROUP BY HAVING COUNT(`*`) = 1
```sql
SELECT id, username, email, password
FROM (
  SELECT * FROM user_example1
  UNION ALL
  SELECT * FROM user_example2
) AS u
GROUP BY id, username, email, password
HAVING COUNT(*) = 1;
```
実行結果(MySQL WorkBench)
![スクリーンショット 2025-05-21 22.56.31.png](/images/スクリーンショット%202025-05-21%2022.56.31.png)
*メリット*
・MySQLバージョンを問わない
・テーブル間で追加/削除されているデータの差異を確認できる
*デメリット*
・取得結果が縦並びになるので、差分発生箇所が多いと確認に時間がかかる


# まとめ
・MySQLバージョンによる問題がなく最速で差分発生箇所を特定したいならEXCEPTを使用する
・テーブル間でデータの追加/削除の差異を確認したいならUNION ALL ＋ GROUP BY HAVING COUNT(`*`)=1の方式で確認する
・より差分を分かりやすく確認したいなら `INNER JOIN + WHERE NOT`を活用して取得を行う
