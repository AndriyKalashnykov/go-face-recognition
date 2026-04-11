package entity

import (
	"reflect"
	"testing"
)

func TestNewPerson(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name       string
		id         int
		personName string
		images     []string
		want       *Person
	}{
		{
			name:       "single image",
			id:         1,
			personName: "Alice",
			images:     []string{"a.jpg"},
			want:       &Person{ID: 1, Name: "Alice", ImagesPath: []string{"a.jpg"}},
		},
		{
			name:       "multiple images",
			id:         42,
			personName: "Bob",
			images:     []string{"b1.jpg", "b2.jpg", "b3.jpg"},
			want:       &Person{ID: 42, Name: "Bob", ImagesPath: []string{"b1.jpg", "b2.jpg", "b3.jpg"}},
		},
		{
			name:       "zero-valued id",
			id:         0,
			personName: "",
			images:     nil,
			want:       &Person{ID: 0, Name: "", ImagesPath: nil},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			got := NewPerson(tc.id, tc.personName, tc.images)
			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("NewPerson(%d, %q, %v) = %+v, want %+v", tc.id, tc.personName, tc.images, got, tc.want)
			}
		})
	}
}

func TestNewPerson_ReturnsNewInstance(t *testing.T) {
	t.Parallel()

	images := []string{"x.jpg"}
	p1 := NewPerson(1, "Alice", images)
	p2 := NewPerson(1, "Alice", images)

	if p1 == p2 {
		t.Errorf("NewPerson should return a distinct instance on each call, got identical pointers")
	}
}
