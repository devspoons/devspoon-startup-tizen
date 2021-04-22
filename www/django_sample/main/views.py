from django.shortcuts import render

# Create your views here.
def home(request):
    return render(request, 'home.html')
    # 이전 if로 세션 처리를 했던 내용들을 template의 home.html로 이동시킴, html에서 session 처리가 가능함!
