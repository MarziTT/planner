"""add legacy wake time to user patterns

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Create Date: 2026-08-05 18:40:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = "d4e5f6a7b8c9"
down_revision = "c3d4e5f6a7b8"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("user_patterns")}
    if "wake_time" not in columns:
        op.add_column(
            "user_patterns",
            sa.Column("wake_time", sa.String(length=5), nullable=True),
        )


def downgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("user_patterns")}
    if "wake_time" in columns:
        op.drop_column("user_patterns", "wake_time")
