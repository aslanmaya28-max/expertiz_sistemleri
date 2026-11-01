import json
import os
import subprocess
import sys

import pytest

from yerimebak_ai_v5.services.payment_service import PaymentService, credit_refusal


@pytest.mark.parametrize("amount", [0, -1, True, 1.5, "1", None])
def test_deduction_requires_positive_integer(amount):
    result = PaymentService().deduct_credits(1, amount=amount)
    assert result["success"] is False


def test_insufficient_credit_refusal_is_payment_required():
    status, code, message = credit_refusal("insufficient_credits", 0)
    assert (status, code) == (402, "insufficient_credits")
    assert message


def test_package_environment_override_and_registration_gift():
    packages = {"ozel": {"credits": 20, "price": 1500, "name": "Özel", "popular": False}}
    env = {**os.environ, "CREDIT_PACKAGES": json.dumps(packages), "FREE_CREDITS_ON_REGISTER": "3"}
    result = subprocess.run([sys.executable, "-c",
        "import json; from yerimebak_ai_v5.services.payment_service import CREDIT_PACKAGES, FREE_CREDITS_ON_REGISTER; "
        "print(json.dumps([CREDIT_PACKAGES, FREE_CREDITS_ON_REGISTER]))"],
        env=env, capture_output=True, text=True, check=True)
    assert json.loads(result.stdout) == [packages, 3]
