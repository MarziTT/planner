from __future__ import annotations

from flask import Blueprint, g, request

from ..extensions import db
from ..models import Profile
from .common import auth_required, success


profile_bp = Blueprint("profile", __name__)


def _profile_to_dict(profile: Profile):
    return {
        "gender": profile.gender,
        "age": profile.age,
        "city": profile.city,
        "bio": profile.bio,
        "fitnessGoal": profile.fitness_goal,
        "identity": profile.identity,
        "routineStart": profile.routine_start,
        "routineEnd": profile.routine_end,
        "focusArea": profile.focus_area,
        "wantsFitness": profile.wants_fitness,
        "fitnessMode": profile.fitness_mode,
    }


@profile_bp.get("/profile")
@auth_required
def get_profile():
    profile = Profile.query.filter_by(user_id=g.current_user.id).first()
    return success({"item": _profile_to_dict(profile)})


@profile_bp.put("/profile")
@auth_required
def update_profile():
    profile = Profile.query.filter_by(user_id=g.current_user.id).first()
    payload = request.get_json(silent=True) or {}
    profile.gender = payload.get("gender", profile.gender) or ""
    profile.age = payload.get("age", profile.age)
    profile.city = payload.get("city", profile.city) or ""
    profile.bio = payload.get("bio", profile.bio) or ""
    profile.fitness_goal = payload.get("fitnessGoal", profile.fitness_goal) or ""
    profile.identity = payload.get("identity", profile.identity) or "worker"
    profile.routine_start = payload.get("routineStart", profile.routine_start) or "09:00"
    profile.routine_end = payload.get("routineEnd", profile.routine_end) or "18:00"
    profile.focus_area = payload.get("focusArea", profile.focus_area) or ""
    profile.wants_fitness = bool(payload.get("wantsFitness", profile.wants_fitness))
    profile.fitness_mode = payload.get("fitnessMode", profile.fitness_mode) or "self"
    g.current_user.onboarding_done = True
    db.session.commit()
    return success({"item": _profile_to_dict(profile), "onboardingDone": True})
