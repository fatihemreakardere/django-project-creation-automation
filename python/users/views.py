from django.http import HttpResponse


def index(request):
    return HttpResponse("Users app index page")