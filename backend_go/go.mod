module household-go

// Go 1.22 introduced improved range-over-integers and better toolchain support.
// Always pin a specific Go version in go.mod — it controls language semantics,
// not just which compiler you use.
go 1.22

require (
	// gin is the most popular Go HTTP framework. It uses a radix-tree router
	// (httprouter under the hood) which is O(log n) vs net/http's O(n) map lookup.
	github.com/gin-gonic/gin v1.9.1

	// golang-jwt is the community-maintained fork of dgrijalva/jwt-go (archived).
	// v5 adds strict validation by default (exp, nbf, iat are checked automatically).
	github.com/golang-jwt/jwt/v5 v5.2.1

	// godotenv loads .env files into os.Getenv() — same concept as Node's dotenv.
	github.com/joho/godotenv v1.5.1

	// golang.org/x/crypto provides bcrypt — the same algorithm Node's bcryptjs uses.
	// The cost factors are compatible, so existing hashed passwords still work.
	golang.org/x/crypto v0.21.0

	// datatypes provides GORM-compatible JSON column support (for favoriteExpenseCategoryIds).
	gorm.io/datatypes v1.2.0

	// GORM is Go's most popular ORM — conceptually similar to Sequelize.
	// gorm.io/gorm is the core; the driver is separate (like Sequelize dialects).
	gorm.io/driver/mysql v1.5.6
	gorm.io/gorm v1.25.10
)

require (
	github.com/bytedance/sonic v1.9.1 // indirect
	github.com/chenzhuoyu/base64x v0.0.0-20221115062448-fe3a3abad311 // indirect
	github.com/gabriel-vasile/mimetype v1.4.2 // indirect
	github.com/gin-contrib/sse v0.1.0 // indirect
	github.com/go-playground/locales v0.14.1 // indirect
	github.com/go-playground/universal-translator v0.18.1 // indirect
	github.com/go-playground/validator/v10 v10.14.0 // indirect
	github.com/go-sql-driver/mysql v1.7.0 // indirect
	github.com/goccy/go-json v0.10.2 // indirect
	github.com/jinzhu/inflection v1.0.0 // indirect
	github.com/jinzhu/now v1.1.5 // indirect
	github.com/json-iterator/go v1.1.12 // indirect
	github.com/klauspost/cpuid/v2 v2.2.4 // indirect
	github.com/leodido/go-urn v1.2.4 // indirect
	github.com/mattn/go-isatty v0.0.19 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.2 // indirect
	github.com/pelletier/go-toml/v2 v2.0.8 // indirect
	github.com/twitchyliquid64/golang-asm v0.15.1 // indirect
	github.com/ugorji/go/codec v1.2.11 // indirect
	golang.org/x/arch v0.3.0 // indirect
	golang.org/x/net v0.21.0 // indirect
	golang.org/x/sys v0.18.0 // indirect
	golang.org/x/text v0.14.0 // indirect
	google.golang.org/protobuf v1.30.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
