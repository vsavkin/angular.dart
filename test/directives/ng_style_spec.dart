library ng_style_spec;

import '../_specs.dart';
import '../_test_bed.dart';
import 'dart:html' as dom;

main() => describe('NgStyle', () {
  TestBed _;

  beforeEach(beforeEachTestBed((tb) => _ = tb));

  it('should set', () {
    dom.Element element = _.compile('<div ng-style="{height: \'40px\'}"></div>')[0];
    _.rootScope.$digest();
    expect(element.style.height).toEqual('40px');
  });


  it('should silently ignore undefined style', () {
    dom.Element element = _.compile('<div ng-style="myStyle"></div>')[0];
    _.rootScope.$digest();
    expect(element.classes.contains('ng-exception')).toBeFalsy();
  });


  describe('preserving styles set before and after compilation', () {
    var scope, preCompStyle, preCompVal, postCompStyle, postCompVal, element;

    beforeEach(inject(() {
      preCompStyle = 'width';
      preCompVal = '300px';
      postCompStyle = 'height';
      postCompVal = '100px';
      element = $('<div ng-style="styleObj"></div>');
      element[0].style.setProperty(preCompStyle, preCompVal);
      document.body.append(element[0]);
      _.compile(element);
      scope = _.rootScope;
      scope.styleObj = {'margin-top': '44px'};
      scope.$apply();
      element[0].style.setProperty(postCompStyle, postCompVal);
    }));

    afterEach(() {
      element.remove();
    });


    iit('should not mess up stuff after compilation', () {
      element[0].style.setProperty('margin', '44px');
      expect(element.css(preCompStyle)).toBe(preCompVal);
      expect(element.css('margin-top')).toBe('44px');
      expect(element.css(postCompStyle)).toBe(postCompVal);
    });
    /*

    it('should not mess up stuff after $apply with no model changes', function() {
      element.css('padding-top', '33px');
      scope.$apply();
      expect(element.css(preCompStyle)).toBe(preCompVal);
      expect(element.css('margin-top')).toBe('44px');
      expect(element.css(postCompStyle)).toBe(postCompVal);
      expect(element.css('padding-top')).toBe('33px');
    });


    it('should not mess up stuff after $apply with non-colliding model changes', function() {
      scope.styleObj = {'padding-top': '99px'};
      scope.$apply();
      expect(element.css(preCompStyle)).toBe(preCompVal);
      expect(element.css('margin-top')).not.toBe('44px');
      expect(element.css('padding-top')).toBe('99px');
      expect(element.css(postCompStyle)).toBe(postCompVal);
    });


    it('should overwrite original styles after a colliding model change', function() {
      scope.styleObj = {'height': '99px', 'width': '88px'};
      scope.$apply();
      expect(element.css(preCompStyle)).toBe('88px');
      expect(element.css(postCompStyle)).toBe('99px');
      scope.styleObj = {};
      scope.$apply();
      expect(element.css(preCompStyle)).not.toBe('88px');
      expect(element.css(postCompStyle)).not.toBe('99px');
    });
    */
  });
});
