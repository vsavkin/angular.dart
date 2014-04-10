library ng_base_css_spec;

import '../_specs.dart';

@NgComponent(
    selector: 'html-and-css',
    templateUrl: 'simple.html',
    cssUrl: 'simple.css')
class _HtmlAndCssComponent {}

main() => describe('NgBaseCss', () {
  beforeEachModule((Module module) {
    module
      ..type(_HtmlAndCssComponent);
  });

  it('should load css urls from ng-base-css', async((TestBed _, MockHttpBackend backend) {
    backend
      ..expectGET('simple.html').respond('<div>Simple!</div>')
      ..expectGET('base.css').respond('.base{}')
      ..expectGET('simple.css').respond('.simple{}')
      ;

    var element = e('<div ng-base-css="base.css"><html-and-css>ignore</html-and-css></div>');
    _.compile(element);

    microLeap();
    backend.flush();
    microLeap();

    expect(element.children[0].shadowRoot).toHaveHtml(
            '<style>.base{}</style><style>.simple{}</style><div>Simple!</div>'
        );
  }));

  it('ng-base-css should overwrite parent ng-base-csses', async((TestBed _, MockHttpBackend backend) {
    backend
      ..expectGET('simple.html').respond('<div>Simple!</div>')
      ..expectGET('base.css').respond('.base{}')
      ..expectGET('simple.css').respond('.simple{}');

    var element = e('<div ng-base-css="hidden.css"><div ng-base-css="base.css"><html-and-css>ignore</html-and-css></div></div>');
    _.compile(element);

    microLeap();
    backend.flush();
    microLeap();

    expect(element.children[0].children[0].shadowRoot).toHaveHtml(
        '<style>.base{}</style><style>.simple{}</style><div>Simple!</div>'
    );
  }));

  describe('from injector', () {
    var ngBaseCss;
    beforeEachModule((Module module) {
      module.factory(NgBaseCss, (_) => ngBaseCss);
    });

    it('ng-base-css should be available from the injector', async((TestBed _, MockHttpBackend backend) {
      ngBaseCss = new NgBaseCss()
        ..urls = ['injected.css']
        ..attach();

      backend
        ..expectGET('simple.html').respond('<div>Simple!</div>')
        ..expectGET('injected.css').respond('.injected{}')
        ..expectGET('simple.css').respond('.simple{}');

      var element = e('<div><html-and-css>ignore</html-and-css></div></div>');
      _.compile(element);

      microLeap();
      backend.flush();
      microLeap();

      expect(element.children[0].shadowRoot).toHaveHtml(
          '<style>.injected{}</style><style>.simple{}</style><div>Simple!</div>'
      );
    }));
  });
});
