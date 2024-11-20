from flask import Flask, render_template, request, redirect, url_for, session
import mysql.connector

app = Flask(__name__)
app.secret_key = 'your_secret_key'

# Custom filter to enumerate
@app.template_filter('enumerate')
def _enumerate(iterable):
    return enumerate(iterable)

# Register the custom filter
app.jinja_env.filters['enumerate'] = _enumerate

def get_db_connection():
    connection = mysql.connector.connect(
        host="localhost",
        user="root",
        password="chandu@123S",
        database="environmentalimpacttracker"
    )
    return connection

@app.route('/')
def home():
    return render_template('home.html')

@app.route('/login', methods=['GET', 'POST'])
def login_page():
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT User_ID, Email, Password, RoleRank FROM User WHERE Email = %s AND Password = %s", (email, password))
        user = cursor.fetchone()
        connection.close()
        if user:
            session['user_id'] = user['User_ID']
            session['role_rank'] = user.get('RoleRank').lower()
            if session['role_rank'] == 'admin':
                return redirect(url_for('admin_dashboard'))
            elif session['role_rank'] == 'user':
                return redirect(url_for('user_dashboard'))
            else:
                return f"Invalid role rank: {session['role_rank']}"
        else:
            return "Invalid credentials"
    return render_template('login.html')

@app.route('/admin_dashboard')
def admin_dashboard():
    # Ensure the user is an admin
    if 'user_id' not in session or session.get('role_rank') != 'admin':
        return redirect(url_for('login_page'))

    # Fetch user data for display in the admin dashboard
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)
    cursor.execute("SELECT User_ID, Email, RoleRank FROM User")
    users = cursor.fetchall()
    connection.close()

    return render_template('admin_dashboard.html', users=users)

@app.route('/user_dashboard', methods=['GET', 'POST'])
def user_dashboard():
    if 'user_id' not in session or session.get('role_rank') != 'user':
        return redirect(url_for('login_page'))

    user_id = session['user_id']
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)

    # Handle form submission for log insertion
    if request.method == 'POST':
        log_type = request.form.get('log_type')  # .get() is safer in case the form fields are missing
        month = request.form.get('month')
        usage = request.form.get('usage')
        cost = request.form.get('cost')
        log_date = request.form.get('log_date')

        if log_type == 'electricity':
            cursor.execute("""
                INSERT INTO Electricity_Logs (User_ID, Month, Electricity_Usage, Electricity_Cost, Log_Date)
                VALUES (%s, %s, %s, %s, %s)
            """, (user_id, month, usage, cost, log_date))
        elif log_type == 'water':
            cursor.execute("""
                INSERT INTO Water_Logs (User_ID, Month, Water_Usage, Water_Cost, Log_Date)
                VALUES (%s, %s, %s, %s, %s)
            """, (user_id, month, usage, cost, log_date))

        connection.commit()

    # Fetch suggestions
    cursor.execute("SELECT CheckWaterUsageThreshold(%s, %s) as water_exceeds", (user_id, 'January'))
    water_exceeds = cursor.fetchone()['water_exceeds']
    cursor.execute("SELECT CheckElectricityUsageThreshold(%s, %s) as electricity_exceeds", (user_id, 'January'))
    electricity_exceeds = cursor.fetchone()['electricity_exceeds']

    suggestions = []
    if water_exceeds:
        suggestions.append("Suggestion: Your water usage is above the threshold. Try to reduce it to save the environment!")
    if electricity_exceeds:
        suggestions.append("Suggestion: Your electricity usage is above the threshold. Try to reduce it to save the environment!")
    if not water_exceeds and not electricity_exceeds:
        suggestions.append("Compliment: Great job! Your usage is within the recommended limits.")

    # Fetch rankings
    cursor.execute("""
        SELECT u.User_ID, u.Email,
        (SELECT COALESCE(SUM(w.Water_Usage), 0) FROM Water_Logs w WHERE w.User_ID = u.User_ID)
        + (SELECT COALESCE(SUM(e.Electricity_Usage), 0) FROM Electricity_Logs e WHERE e.User_ID = u.User_ID)
        AS Total_Usage
        FROM User u
        ORDER BY Total_Usage DESC
    """)
    rankings = cursor.fetchall()
    connection.close()
    return render_template('user_dashboard.html', suggestions=suggestions, rankings=rankings)

# Route to Delete User (Admin Action)
# Route to Delete User (Admin Action)
@app.route('/delete_user/<int:user_id>', methods=['POST'])
def delete_user(user_id):
    if 'user_id' not in session or session.get('role_rank') != 'admin':
        return redirect(url_for('login_page'))

    connection = get_db_connection()
    cursor = connection.cursor()
    cursor.execute("DELETE FROM User WHERE User_ID = %s", (user_id,))
    connection.commit()
    connection.close()

    # Redirect to manage users or admin dashboard as needed
    return redirect(url_for('manage_users'))

@app.route('/generate_report', methods=['POST'])
def generate_report():
    if 'user_id' not in session or session.get('role_rank') != 'admin':
        return redirect(url_for('login_page'))

    user_id = request.form['user_id']
    
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)

    # Fetch suggestions for the user
    cursor.execute("SELECT Suggestion_Text FROM Suggestions WHERE User_ID = %s", (user_id,))
    suggestions = cursor.fetchall()

    # Fetch electricity and water logs for the user
    cursor.execute("SELECT * FROM Water_Logs WHERE User_ID = %s", (user_id,))
    water_logs = cursor.fetchall()
    
    cursor.execute("SELECT * FROM Electricity_Logs WHERE User_ID = %s", (user_id,))
    electricity_logs = cursor.fetchall()
    
    connection.close()

    # Render or download report based on the collected data
    # Here, we redirect to a new template to display the report (you can also generate a PDF if needed)
    return render_template('user_report.html', user_id=user_id, suggestions=suggestions, water_logs=water_logs, electricity_logs=electricity_logs)

# Manage Users (Admin View)
@app.route('/manage_users')
def manage_users():
    if 'user_id' not in session or session.get('role_rank') != 'admin':
        return redirect(url_for('login_page'))

    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)
    cursor.execute("SELECT User_ID, Email, RoleRank FROM User")
    users = cursor.fetchall()
    connection.close()

    return render_template('manage_users.html', users=users)

@app.route('/update_user/<int:user_id>', methods=['GET', 'POST'])
def update_user(user_id):
    if request.method == 'POST':
        new_email = request.form['email']
        
        connection = get_db_connection()
        cursor = connection.cursor()
        cursor.execute("UPDATE User SET Email = %s WHERE User_ID = %s", (new_email, user_id))
        connection.commit()
        connection.close()
        
        return redirect(url_for('admin_dashboard'))
    
    # Fetch the user's current details to pre-fill the update form
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)
    cursor.execute("SELECT * FROM User WHERE User_ID = %s", (user_id,))
    user = cursor.fetchone()
    connection.close()
    
    return render_template('update_user.html', user=user)

@app.route('/delete_user_from_dashboard/<int:user_id>', methods=['POST'])
def delete_user_from_dashboard(user_id):
    if 'user_id' not in session or session.get('role_rank') != 'admin':
        return redirect(url_for('login_page'))

    connection = get_db_connection()
    cursor = connection.cursor()
    
    # Delete associated logs first (electricity and water logs)
    cursor.execute("DELETE FROM Electricity_Logs WHERE User_ID = %s", (user_id,))
    cursor.execute("DELETE FROM Water_Logs WHERE User_ID = %s", (user_id,))
    connection.commit()
     # Delete related records in 'rankings' table before deleting user
    cursor.execute("DELETE FROM Rankings WHERE User_ID = %s", (user_id,))
    # Now delete the user
    cursor.execute("DELETE FROM User WHERE User_ID = %s", (user_id,))
    connection.commit()
    
    connection.close()
    
    return redirect(url_for('manage_users'))

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login_page'))

if __name__ == '__main__':
    app.run(debug=True)
