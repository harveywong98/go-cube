package model

type Cube struct {
	Name       string               `yaml:"name"`
	SQL        string               `yaml:"sql"`
	SQLTable   string               `yaml:"sql_table"`
	Dimensions map[string]Dimension `yaml:"dimensions"`
	Measures   map[string]Measure   `yaml:"measures"`
	Segments   map[string]Segment   `yaml:"segments,omitempty"`
}

type Dimension struct {
	SQL        string `yaml:"sql"`
	Type       string `yaml:"type"`
	Title      string `yaml:"title,omitempty"`
	PrimaryKey bool   `yaml:"primary_key,omitempty"`
}

type Measure struct {
	SQL   string `yaml:"sql"`
	Type  string `yaml:"type"`
	Title string `yaml:"title,omitempty"`
}

type Segment struct {
	SQL string `yaml:"sql"`
}


func (c *Cube) GetField(name string) (Field, bool) {
	if dim, ok := c.Dimensions[name]; ok {
		return Field{
			Name: name,
			SQL:  dim.SQL,
			Type: dim.Type,
		}, true
	}

	if measure, ok := c.Measures[name]; ok {
		return Field{
			Name: name,
			SQL:  measure.SQL,
			Type: measure.Type,
		}, true
	}

	return Field{}, false
}

func (c *Cube) GetSQLTable() string {
	if c.SQLTable != "" {
		return c.SQLTable
	}
	// 对于复杂子查询，需要添加别名
	if c.SQL != "" {
		return "(" + c.SQL + ") AS " + c.Name
	}
	return ""
}

type Field struct {
	Name string
	SQL  string
	Type string
}
