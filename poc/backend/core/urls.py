"""
core 앱 URL 설정.

API 계약(Base: /api/v1):
- GET    /exposure-media
- POST   /training-sessions
- PATCH  /training-sessions/{id}
- POST   /training-sessions/{id}/vas
- POST   /urge-surfing
- GET    /dashboard/vas-trend
"""
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    ExposureMediaViewSet,
    TrainingSessionViewSet,
    UrgeSurfingViewSet,
    VasTrendView,
)

router = DefaultRouter()
router.register("exposure-media", ExposureMediaViewSet, basename="exposure-media")
router.register("training-sessions", TrainingSessionViewSet, basename="training-sessions")
router.register("urge-surfing", UrgeSurfingViewSet, basename="urge-surfing")

urlpatterns = [
    path("dashboard/vas-trend", VasTrendView.as_view(), name="vas-trend"),
    path("", include(router.urls)),
]
