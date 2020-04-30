package main

import "testing"

func TestTestUtils_SameElements(t *testing.T) {
	// The same slices...
	if !sameElements([]string{}, []string{}) {
		t.Errorf("Two empty slices should be the same")
	}
	if !sameElements([]string{"x"}, []string{"x"}) {
		t.Errorf("{x} and {x} should be the same")
	}
	if !sameElements([]string{"x", "y", "z"}, []string{"x", "y", "z"}) {
		t.Errorf("{x,y,z} and {x,y,z} should be the same")
	}

	// Mixed up slices
	if !sameElements([]string{"x", "y", "z"}, []string{"y", "z", "x"}) {
		t.Errorf("{x,y,z} and {y,z,x} should be the same")
	}

	// Same length, different elements
	if sameElements([]string{"x", "y", "z"}, []string{"y", "z", "z"}) {
		t.Errorf("{x,y,z} and {y,z,z} should be the different")
	}

	// Different length
	if sameElements([]string{}, []string{"x", "y", "z"}) {
		t.Errorf("{} and {x,y,z} should be the different")
	}
	if sameElements([]string{"x", "y"}, []string{"x", "y", "z"}) {
		t.Errorf("{x,y} and {x,y,z} should be the different")
	}
}
