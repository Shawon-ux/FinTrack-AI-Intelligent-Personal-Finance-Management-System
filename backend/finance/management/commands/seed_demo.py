import random
from datetime import timedelta
from decimal import Decimal
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone
from finance.ml import categorizer
from finance.models import *

User = get_user_model()
SPEND = [  # (category, sub, merchant, desc, lo, hi, weight)
    ("Food", "Fast Food", "KFC", "Dinner at KFC", 300, 700, 1.5), ("Food", "Restaurant", "Cafe Mocha", "Lunch", 150, 450, 2),
    ("Food", "Groceries", "Shwapno", "Weekly grocery", 600, 1800, 0.7), ("Transport", "Ride", "Pathao", "Pathao ride", 80, 300, 5),
    ("Transport", "Fuel", "Padma Oil", "Fuel", 500, 1500, 1), ("Shopping", "Clothing", "Aarong", "Clothes shopping", 800, 3000, 1.2),
    ("Entertainment", "Streaming", "Netflix", "Netflix subscription", 400, 400, 0), ("Entertainment", "Movies", "Star Cineplex", "Movie night", 400, 1200, 1.2),
    ("Health", "Pharmacy", "Lazz Pharma", "Medicine", 150, 900, 1), ("Personal Care", "Salon", "Salon X", "Haircut", 200, 600, 1),
]


class Command(BaseCommand):
    def handle(self, *a, **k):
        random.seed(7)
        admin, c = User.objects.get_or_create(username="admin@fintrack.ai", defaults=dict(email="admin@fintrack.ai", is_staff=True, is_superuser=True, first_name="Admin"))
        admin.set_password("admin1234"); admin.save(); Profile.objects.get_or_create(user=admin)
        u, _ = User.objects.get_or_create(username="demo@fintrack.ai", defaults=dict(email="demo@fintrack.ai", first_name="Rafi"))
        u.set_password("demo1234"); u.save()
        u.transactions.all().delete()
        p, _ = Profile.objects.get_or_create(user=u)
        p.monthly_income = 65000; p.savings_target = 10000; p.is_premium = True; p.onboarded = True; p.save()
        u.accounts.all().delete()
        cash = Account.objects.create(user=u, name="Cash", kind="cash", opening_balance=5000)
        bank = Account.objects.create(user=u, name="City Bank", kind="bank", opening_balance=30000)
        bk = Account.objects.create(user=u, name="bKash", kind="wallet", opening_balance=2000)
        now = timezone.now(); today = timezone.localdate()
        for back in range(130, -1, -1):
            d = now - timedelta(days=back)
            if d.day == 1:
                Transaction.objects.create(user=u, account=bank, transaction_type="income", amount=65000, category="Income", subcategory="Salary",
                                           description="Monthly salary", merchant_name="Employer Ltd", payment_method="bank", transaction_date=d.replace(hour=10))
                Transaction.objects.create(user=u, account=bank, transaction_type="expense", amount=15000, category="Bills", subcategory="Rent",
                                           description="House rent", payment_method="bank", transaction_date=d.replace(hour=11), is_recurring=True)
            if d.day == 5:
                Transaction.objects.create(user=u, account=bank, transaction_type="expense", amount=random.randint(1800, 2400), category="Bills",
                                           subcategory="Utilities", description="Electricity bill", payment_method="bank", transaction_date=d.replace(hour=12))
                Transaction.objects.create(user=u, account=bank, transaction_type="expense", amount=1200, category="Bills", subcategory="Internet",
                                           description="Wifi bill", merchant_name="Link3", payment_method="bank", transaction_date=d.replace(hour=12))
            if d.day == 20 and back > 3:
                Transaction.objects.create(user=u, account=bk, transaction_type="income", amount=random.randint(4000, 9000), category="Income", subcategory="Freelance",
                                           description="Freelance client payment", payment_method="bkash", transaction_date=d.replace(hour=15))
            for _ in range(random.choice([0, 1, 1, 2])):
                cat, sub, m, desc, lo, hi, w = random.choices(SPEND, weights=[x[6] or 0.2 for x in SPEND])[0]
                boost = 1 + (130 - back) / 130 * 0.25  # mild upward trend
                Transaction.objects.create(user=u, account=random.choice([cash, bk]), transaction_type="expense", amount=round(random.uniform(lo, hi) * boost),
                                           category=cat, subcategory=sub, merchant_name=m, description=desc, payment_method=random.choice(["cash", "bkash", "card"]),
                                           transaction_date=d.replace(hour=random.choice([9, 13, 14, 19, 20, 21])))
        s = today.replace(day=1)
        Budget.objects.filter(user=u).delete()
        Budget.objects.create(user=u, name="Monthly Budget", total_limit=40000, start_date=s, end_date=(s + timedelta(days=32)).replace(day=1) - timedelta(days=1),
                              category_limits={"Food": 9000, "Transport": 4000, "Shopping": 4000, "Entertainment": 2500, "Bills": 19000})
        SavingsGoal.objects.filter(user=u).delete()
        for n, t, sv, mo in [("New Laptop", 80000, 35000, 5), ("Emergency Fund", 100000, 40000, 12), ("Vacation", 50000, 15000, 8)]:
            SavingsGoal.objects.create(user=u, name=n, target_amount=t, saved_amount=sv, target_date=today + timedelta(days=30 * mo))
        RecurringTransaction.objects.filter(user=u).delete()
        RecurringTransaction.objects.create(user=u, title="House rent", amount=15000, category="Bills", frequency="monthly", next_due=today + timedelta(days=2))
        RecurringTransaction.objects.create(user=u, title="Netflix", amount=400, category="Entertainment", frequency="monthly", next_due=today + timedelta(days=9))
        # one planted unusual transaction for the anomaly demo
        t = Transaction.objects.create(user=u, account=cash, transaction_type="expense", amount=8500, category="Food", subcategory="Restaurant",
                                       merchant_name="Unknown Resort", description="Dinner", transaction_date=now - timedelta(hours=3))
        from finance import services
        services.after_save(t)
        ModelVersion.objects.all().delete()
        ModelVersion.objects.create(name="categorizer", version=categorizer.VERSION, metrics=categorizer.metrics(), trained_on="synthetic")
        ModelVersion.objects.create(name="forecaster", version="fc-ridge-lag-1.0", metrics={"validation": "time-based 80/20 backtest vs mean baseline"}, trained_on="per-user history")
        ModelVersion.objects.create(name="anomaly", version="anom-iforest-1.0", metrics={"method": "robust z-score + IsolationForest"}, trained_on="per-user history")
        self.stdout.write("Seeded. demo@fintrack.ai / demo1234 ; admin@fintrack.ai / admin1234")
