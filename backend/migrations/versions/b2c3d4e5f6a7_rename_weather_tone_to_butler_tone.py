"""rename weather_tone to butler_tone

Revision ID: b2c3d4e5f6a7
Revises: 7960ff215c9f
Create Date: 2026-08-05 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = 'b2c3d4e5f6a7'
down_revision = '7960ff215c9f'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("settings")}
    if "weather_tone" in columns and "butler_tone" not in columns:
        op.alter_column("settings", "weather_tone", new_column_name="butler_tone")
    elif "butler_tone" not in columns:
        op.add_column("settings", sa.Column("butler_tone", sa.Text(), nullable=True))


def downgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("settings")}
    if "butler_tone" in columns and "weather_tone" not in columns:
        op.alter_column("settings", "butler_tone", new_column_name="weather_tone")
    elif "weather_tone" not in columns:
        op.add_column("settings", sa.Column("weather_tone", sa.Text(), nullable=True))
